use html2text::{config::Config, render::PlainDecorator};
use rustler::{error::Error, Atom, NifResult, Term};

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

#[cfg(test)]
mod tests {
    use super::*;

    // Options

    #[test]
    fn default_values() {
        let opts = Options::default();

        assert_eq!(opts.width, 80);
        assert_eq!(opts.min_wrap_width, 3);
        assert!(opts.decorate);
        assert!(opts.link_footnotes);
        assert!(opts.table_borders);
        assert!(opts.wrap_links);
        assert!(opts.unicode_strikeout);
        assert!(!opts.pad_block_width);
        assert!(!opts.allow_width_overflow);
        assert!(!opts.raw);
    }

    #[test]
    fn converts_to_html2text_config() {
        let opts = Options::default();
        let config: Config<PlainDecorator> = Config::from(opts);
        let result = config.string_from_read("<p>Test</p>".as_bytes(), 80);

        assert!(result.is_ok());
    }

    #[test]
    fn converts_with_all_options_modified() {
        let opts = Options {
            width: 100,
            decorate: false,
            link_footnotes: false,
            table_borders: false,
            pad_block_width: true,
            allow_width_overflow: true,
            min_wrap_width: 5,
            raw: true,
            wrap_links: false,
            unicode_strikeout: false,
        };
        let config: Config<PlainDecorator> = Config::from(opts);
        let result = config.string_from_read("<p>Test</p>".as_bytes(), 100);

        assert!(result.is_ok());
    }

    // HTML conversion

    fn convert(html: &str, opts: Options) -> String {
        let width = opts.width;
        Config::from(opts)
            .string_from_read(html.as_bytes(), width)
            .unwrap()
    }

    #[test]
    fn simple_paragraph() {
        let result = convert("<p>Hello World</p>", Options::default());
        assert!(result.contains("Hello World"));
    }

    #[test]
    fn empty_html() {
        let result = convert("", Options::default());
        assert!(result.is_empty());
    }

    #[test]
    fn respects_width_limit() {
        let opts = Options {
            width: 10,
            ..Default::default()
        };
        let result = convert("<p>This is a long sentence</p>", opts);

        assert!(result.lines().all(|line| line.len() <= 12));
    }

    #[test]
    fn decoration_affects_output() {
        let html = "<p><strong>Bold</strong></p>";

        let with = convert(
            html,
            Options {
                decorate: true,
                ..Default::default()
            },
        );
        let without = convert(
            html,
            Options {
                decorate: false,
                ..Default::default()
            },
        );

        assert_ne!(with, without);
    }

    #[test]
    fn table_borders_affect_output() {
        let html = "<table><tr><td>Cell</td></tr></table>";

        let with = convert(
            html,
            Options {
                table_borders: true,
                ..Default::default()
            },
        );
        let without = convert(
            html,
            Options {
                table_borders: false,
                ..Default::default()
            },
        );

        assert_ne!(with, without);
    }

    #[test]
    fn handles_unicode() {
        let result = convert("<p>Привіт 你好 🎉</p>", Options::default());

        assert!(result.contains("Привіт"));
        assert!(result.contains("你好"));
        assert!(result.contains("🎉"));
    }

    #[test]
    fn handles_special_characters() {
        let result = convert("<p>&amp; &lt; &gt;</p>", Options::default());

        assert!(result.contains("&"));
        assert!(result.contains("<"));
        assert!(result.contains(">"));
    }
}
