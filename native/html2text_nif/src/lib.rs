use rustler::{NifResult, Env, Atom, Term};
use std::io::Cursor;
use html2text::from_read;

#[rustler::nif(schedule = "DirtyCpu")]
fn do_convert(env: Env, html: String, width_term: Term) -> NifResult<String> {
    let cursor = Cursor::new(html.as_bytes());

    // Determine width - parameters are already validated by Elixir guard
    let actual_width = if let Ok(atom) = width_term.decode::<Atom>() {
        let infinity_atom = Atom::from_str(env, "infinity")?;
        if atom == infinity_atom {
            usize::MAX
        } else {
            unreachable!() // guard should filter this out
        }
    } else if let Ok(width) = width_term.decode::<usize>() {
        width
    } else {
        unreachable!() // guard should filter this out
    };

    match from_read(cursor, actual_width) {
        Ok(text) => Ok(text),
        Err(e) => Err(rustler::Error::Term(Box::new(e.to_string()))),
    }
}

rustler::init!("Elixir.HTML2Text");
