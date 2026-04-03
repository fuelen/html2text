use html2text::{
    config::{self, Config, ImageRenderMode},
    render::{PlainDecorator, RichAnnotation, RichDecorator, TaggedLine, TextDecorator},
};
use rustler::{error::Error, Atom, Encoder, Env, NifResult, Term};
use std::collections::HashSet;
use std::sync::{LazyLock, Mutex};

type ConfigResult<T> = Result<Config<T>, html2text::Error>;

static INTERNED: LazyLock<Mutex<HashSet<&'static str>>> =
    LazyLock::new(|| Mutex::new(HashSet::new()));

fn intern(s: String) -> &'static str {
    let mut set = INTERNED.lock().unwrap();
    if let Some(&existing) = set.get(s.as_str()) {
        existing
    } else {
        let leaked = Box::leak(s.into_boxed_str());
        set.insert(leaked);
        leaked
    }
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
        infinity,
        width,
        decorate,
        link_footnotes,
        table_borders,
        pad_block_width,
        allow_width_overflow,
        min_wrap_width,
        raw,
        wrap_links,
        unicode_strikeout,
        empty_img_mode,
        ignore,
        replace,
        filename,
        // rich annotations
        default,
        emphasis,
        strong,
        strikeout,
        code,
        link,
        image,
        preformat,
        colour,
        bg_colour,
        // rich options
        use_doc_css,
        css,
    }
}

/// Configuration options for HTML to text conversion.
struct Options {
    width: usize,
    decorate: bool,
    link_footnotes: bool,
    table_borders: bool,
    pad_block_width: bool,
    allow_width_overflow: bool,
    min_wrap_width: usize,
    raw: bool,
    wrap_links: bool,
    unicode_strikeout: bool,
    empty_img_mode: Option<ImageRenderMode>,
    use_doc_css: bool,
    css: Option<String>,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            width: 80,
            decorate: true,
            link_footnotes: true,
            table_borders: true,
            pad_block_width: false,
            allow_width_overflow: false,
            min_wrap_width: 3,
            raw: false,
            wrap_links: true,
            unicode_strikeout: true,
            empty_img_mode: None,
            use_doc_css: false,
            css: None,
        }
    }
}

/// Applies shared options to any Config<D>.
fn apply_shared_options<D: TextDecorator>(
    mut cfg: Config<D>,
    options: &Options,
) -> ConfigResult<D> {
    cfg = cfg.max_wrap_width(options.width);
    if !options.table_borders {
        cfg = cfg.no_table_borders();
    }
    if options.pad_block_width {
        cfg = cfg.pad_block_width();
    }
    if options.allow_width_overflow {
        cfg = cfg.allow_width_overflow();
    }
    if options.raw {
        cfg = cfg.raw_mode(true);
    }
    if !options.wrap_links {
        cfg = cfg.no_link_wrapping();
    }
    if let Some(img_mode) = options.empty_img_mode {
        cfg = cfg.empty_img_mode(img_mode);
    }
    cfg = cfg.min_wrap_width(options.min_wrap_width);
    if options.use_doc_css {
        cfg = cfg.use_doc_css();
    }
    if let Some(css) = &options.css {
        cfg = cfg.add_css(css)?;
    }
    Ok(cfg)
}

fn build_plain_config(options: &Options) -> ConfigResult<PlainDecorator> {
    let mut cfg = apply_shared_options(config::plain_no_decorate(), options)?;
    if options.decorate {
        cfg = cfg.do_decorate();
    }
    Ok(cfg
        .link_footnotes(options.link_footnotes)
        .unicode_strikeout(options.unicode_strikeout))
}

/// Decodes a Term value into a struct field if successful.
macro_rules! set_if_ok {
    ($config:expr, $field:ident, $val:expr) => {
        if let Ok(v) = $val.decode() {
            $config.$field = v;
        }
    };
}

impl<'a> TryFrom<Term<'a>> for Options {
    type Error = Error;
    fn try_from(term: Term) -> NifResult<Self> {
        let kv_vec = term.decode::<Vec<(Atom, Term)>>()?;
        let mut config = Options::default();

        for (key, val) in kv_vec {
            match key {
                k if k == atoms::width() => {
                    if val.decode::<Atom>().ok() == Some(atoms::infinity()) {
                        config.width = usize::MAX;
                    } else if let Ok(width) = val.decode() {
                        config.width = width;
                    }
                }
                k if k == atoms::decorate() => set_if_ok!(config, decorate, val),
                k if k == atoms::link_footnotes() => set_if_ok!(config, link_footnotes, val),
                k if k == atoms::table_borders() => set_if_ok!(config, table_borders, val),
                k if k == atoms::pad_block_width() => set_if_ok!(config, pad_block_width, val),
                k if k == atoms::allow_width_overflow() => {
                    set_if_ok!(config, allow_width_overflow, val)
                }
                k if k == atoms::min_wrap_width() => set_if_ok!(config, min_wrap_width, val),
                k if k == atoms::raw() => set_if_ok!(config, raw, val),
                k if k == atoms::wrap_links() => set_if_ok!(config, wrap_links, val),
                k if k == atoms::unicode_strikeout() => set_if_ok!(config, unicode_strikeout, val),
                k if k == atoms::use_doc_css() => set_if_ok!(config, use_doc_css, val),
                k if k == atoms::css() => {
                    if let Ok(s) = val.decode::<String>() {
                        config.css = Some(s);
                    }
                }
                k if k == atoms::empty_img_mode() => {
                    if let Ok(atom) = val.decode::<Atom>() {
                        if atom == atoms::ignore() {
                            config.empty_img_mode = Some(ImageRenderMode::IgnoreEmpty);
                        } else if atom == atoms::filename() {
                            config.empty_img_mode = Some(ImageRenderMode::Filename);
                        }
                    } else if let Ok((atom, s)) = val.decode::<(Atom, String)>() {
                        if atom == atoms::replace() {
                            config.empty_img_mode = Some(ImageRenderMode::Replace(intern(s)));
                        }
                    }
                }
                _ => {}
            }
        }

        Ok(config)
    }
}

/// Converts HTML string to plain text with the given configuration.
///
/// # Returns
///
/// `(ok, text)` on success or `(error, reason)` on failure.
#[rustler::nif(schedule = "DirtyCpu")]
fn do_convert(html: String, config_term: Term) -> NifResult<(Atom, String)> {
    let options = Options::try_from(config_term)?;
    let width = options.width;

    let cfg = match build_plain_config(&options) {
        Ok(c) => c,
        Err(e) => return Ok((atoms::error(), e.to_string())),
    };

    match cfg.string_from_read(html.as_bytes(), width) {
        Ok(text) => Ok((atoms::ok(), text)),
        Err(e) => Ok((atoms::error(), e.to_string())),
    }
}

fn encode_annotation<'a>(ann: &RichAnnotation, env: Env<'a>) -> Term<'a> {
    match ann {
        RichAnnotation::Default => atoms::default().encode(env),
        RichAnnotation::Emphasis => atoms::emphasis().encode(env),
        RichAnnotation::Strong => atoms::strong().encode(env),
        RichAnnotation::Strikeout => atoms::strikeout().encode(env),
        RichAnnotation::Code => atoms::code().encode(env),
        RichAnnotation::Link(url) => (atoms::link(), url).encode(env),
        RichAnnotation::Image(src) => (atoms::image(), src).encode(env),
        RichAnnotation::Preformat(cont) => (atoms::preformat(), *cont).encode(env),
        RichAnnotation::Colour(c) => (atoms::colour(), (c.r, c.g, c.b)).encode(env),
        RichAnnotation::BgColour(c) => (atoms::bg_colour(), (c.r, c.g, c.b)).encode(env),
        _ => atoms::default().encode(env),
    }
}

fn encode_line<'a>(line: &TaggedLine<Vec<RichAnnotation>>, env: Env<'a>) -> Term<'a> {
    let segments = line
        .tagged_strings()
        .map(|ts| {
            let annotations = ts
                .tag
                .iter()
                .map(|ann| encode_annotation(ann, env))
                .collect::<Vec<_>>();
            (&ts.s, annotations).encode(env)
        })
        .collect::<Vec<_>>();
    segments.encode(env)
}

fn build_rich_config(options: &Options) -> ConfigResult<RichDecorator> {
    apply_shared_options(config::rich(), options)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn do_convert_rich<'a>(env: Env<'a>, html: String, config_term: Term) -> NifResult<Term<'a>> {
    let options = Options::try_from(config_term)?;
    let width = options.width;

    let cfg = match build_rich_config(&options) {
        Ok(c) => c,
        Err(e) => return Ok((atoms::error(), e.to_string()).encode(env)),
    };

    match cfg.lines_from_read(html.as_bytes(), width) {
        Ok(lines) => {
            let encoded_lines = lines
                .iter()
                .map(|line| encode_line(line, env))
                .collect::<Vec<_>>();
            Ok((atoms::ok(), encoded_lines).encode(env))
        }
        Err(e) => Ok((atoms::error(), e.to_string()).encode(env)),
    }
}

rustler::init!("Elixir.HTML2Text");
