use rustler::{Env, NifResult, Term, Atom};

#[rustler::nif(schedule = "DirtyCpu")]
fn do_convert(env: Env, html: String, config_term: Term) -> NifResult<(Atom, String)> {
    let kv_vec: Vec<(Atom, Term)> = config_term.decode()?;

    let mut width = 80usize;
    let mut decorate = true;
    let mut link_footnotes = true;
    let mut table_borders = true;
    let mut pad_block_width = false;
    let mut allow_width_overflow = false;
    let mut min_wrap_width = 3usize;
    let mut raw = false;
    let mut wrap_links = true;
    let mut unicode_strikeout = true;

    let key_width = Atom::from_str(env, "width")?;
    let key_decorate = Atom::from_str(env, "decorate")?;
    let key_link_footnotes = Atom::from_str(env, "link_footnotes")?;
    let key_table_borders = Atom::from_str(env, "table_borders")?;
    let key_pad_block_width = Atom::from_str(env, "pad_block_width")?;
    let key_allow_width_overflow = Atom::from_str(env, "allow_width_overflow")?;
    let key_min_wrap_width = Atom::from_str(env, "min_wrap_width")?;
    let key_raw = Atom::from_str(env, "raw")?;
    let key_wrap_links = Atom::from_str(env, "wrap_links")?;
    let key_unicode_strikeout = Atom::from_str(env, "unicode_strikeout")?;

    let infinity_atom = Atom::from_str(env, "infinity")?;

    for (key, val) in kv_vec {
        if key == key_width {
            if let Ok(atom) = val.decode::<Atom>() {
                if atom == infinity_atom {
                    width = usize::MAX;
                }
            } else if let Ok(w) = val.decode::<usize>() {
                width = w;
            }
        } else if key == key_decorate {
            decorate = val.decode::<bool>().unwrap_or(false);
        } else if key == key_link_footnotes {
            link_footnotes = val.decode::<bool>().unwrap_or(false);
        } else if key == key_table_borders {
            table_borders = val.decode::<bool>().unwrap_or(true);
        } else if key == key_pad_block_width {
            pad_block_width = val.decode::<bool>().unwrap_or(false);
        } else if key == key_allow_width_overflow {
            allow_width_overflow = val.decode::<bool>().unwrap_or(false);
        } else if key == key_min_wrap_width {
            min_wrap_width = val.decode::<usize>().unwrap_or(3);
        } else if key == key_raw {
            raw = val.decode::<bool>().unwrap_or(false);
        } else if key == key_wrap_links {
            wrap_links = val.decode::<bool>().unwrap_or(true);
        } else if key == key_unicode_strikeout {
            unicode_strikeout = val.decode::<bool>().unwrap_or(true);
        }
    }

    let mut config = html2text::config::plain_no_decorate().max_wrap_width(width);

    if decorate {
        config = config.do_decorate();
    }
    config = config.link_footnotes(link_footnotes);

    if !table_borders {
        config = config.no_table_borders();
    }
    if pad_block_width {
        config = config.pad_block_width();
    }
    if allow_width_overflow {
        config = config.allow_width_overflow();
    }
    config = config.min_wrap_width(min_wrap_width);

    if raw {
        config = config.raw_mode(true);
    }
    if !wrap_links {
        config = config.no_link_wrapping();
    }
    config = config.unicode_strikeout(unicode_strikeout);

    match config.string_from_read(html.as_bytes(), width) {
        Ok(text) => Ok((Atom::from_str(env, "ok")?, text)),
        Err(e) => Ok((Atom::from_str(env, "error")?, e.to_string())),
    }
}

rustler::init!("Elixir.HTML2Text");
