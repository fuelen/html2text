use html2text::{
    config::{Config, ImageRenderMode},
    render::PlainDecorator,
};
use rustler::{error::Error, Atom, NifResult, Term};
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

static INTERNED: LazyLock<Mutex<HashMap<String, &'static str>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn intern(s: String) -> &'static str {
    let mut map = INTERNED.lock().unwrap();
    if let Some(&existing) = map.get(&s) {
        existing
    } else {
        let leaked: &'static str = Box::leak(s.clone().into_boxed_str());
        map.insert(s, leaked);
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
        }
    }
}

impl From<Options> for Config<PlainDecorator> {
    fn from(config: Options) -> Self {
        let mut cfg = html2text::config::plain_no_decorate().max_wrap_width(config.width);

        if config.decorate {
            cfg = cfg.do_decorate();
        }
        if !config.table_borders {
            cfg = cfg.no_table_borders();
        }
        if config.pad_block_width {
            cfg = cfg.pad_block_width();
        }
        if config.allow_width_overflow {
            cfg = cfg.allow_width_overflow();
        }
        if config.raw {
            cfg = cfg.raw_mode(true);
        }
        if !config.wrap_links {
            cfg = cfg.no_link_wrapping();
        }
        if let Some(img_mode) = config.empty_img_mode {
            cfg = cfg.empty_img_mode(img_mode);
        }

        cfg.link_footnotes(config.link_footnotes)
            .min_wrap_width(config.min_wrap_width)
            .unicode_strikeout(config.unicode_strikeout)
    }
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
        let kv_vec: Vec<(Atom, Term)> = term.decode()?;
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
                k if k == atoms::empty_img_mode() => {
                    if let Ok(atom) = val.decode::<Atom>() {
                        if atom == atoms::ignore() {
                            config.empty_img_mode = Some(ImageRenderMode::IgnoreEmpty);
                        } else if atom == atoms::filename() {
                            config.empty_img_mode = Some(ImageRenderMode::Filename);
                        }
                    } else if let Ok(tuple) = val.decode::<(Atom, String)>() {
                        if tuple.0 == atoms::replace() {
                            config.empty_img_mode =
                                Some(ImageRenderMode::Replace(intern(tuple.1)));
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

    match Config::from(options).string_from_read(html.as_bytes(), width) {
        Ok(text) => Ok((atoms::ok(), text)),
        Err(e) => Ok((atoms::error(), e.to_string())),
    }
}

rustler::init!("Elixir.HTML2Text");
