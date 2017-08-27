use v6.d.PREVIEW;
unit module Terminal::Print::DecodedInput;

use Terminal::Print::RawInput;


enum DecodeState < Ground Escape Intermediate >;

enum SpecialKey is export <
     CursorUp CursorDown CursorRight CursorLeft CursorHome CursorEnd
     Delete Insert PageUp PageDown
     F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 F13 F14 F15 F16 F17 F18 F19 F20
     PasteStart PasteEnd
>;

my %special-keys =
    # PC Normal Style      PC Application Style   VT52 Style

    # Cursor Keys
    "\e[A" => CursorUp,    "\eOA" => CursorUp,    "\eA" => CursorUp,
    "\e[B" => CursorDown,  "\eOB" => CursorDown,  "\eB" => CursorDown,
    "\e[C" => CursorRight, "\eOC" => CursorRight, "\eC" => CursorRight,
    "\e[D" => CursorLeft,  "\eOD" => CursorLeft,  "\eD" => CursorLeft,
    "\e[H" => CursorHome,  "\eOH" => CursorHome,
    "\e[F" => CursorEnd,   "\eOF" => CursorEnd,

    # VT220-style Editing Keys
    "\e[2~" => Insert,
    "\e[3~" => Delete,
    "\e[1~" => CursorHome,
    "\e[4~" => CursorEnd,
    "\e[5~" => PageUp,
    "\e[6~" => PageDown,

    # Function Keys
    "\e[11~" => F1,        "\eOP" => F1,          "\eP" => F1,
    "\e[12~" => F2,        "\eOQ" => F2,          "\eQ" => F2,
    "\e[13~" => F3,        "\eOR" => F3,          "\eR" => F3,
    "\e[14~" => F4,        "\eOS" => F4,          "\eS" => F4,
    "\e[15~" => F5,
    "\e[17~" => F6,
    "\e[18~" => F7,
    "\e[19~" => F8,
    "\e[20~" => F9,
    "\e[21~" => F10,
    "\e[23~" => F11,
    "\e[24~" => F12,
    "\e[25~" => F13,
    "\e[26~" => F14,
    "\e[28~" => F15,
    "\e[29~" => F16,
    "\e[31~" => F17,
    "\e[32~" => F18,
    "\e[33~" => F19,
    "\e[34~" => F20,

    # Bracketed Paste
    "\e[200~" => PasteStart,
    "\e[201~" => PasteEnd,
    ;


#| Decode a Terminal::Print::RawInput supply containing special key escapes
multi sub decoded-input-supply(Supply $in-supply) is export {
    my $supplier = Supplier::Preserving.new;

    start react {
        my @partial;
        my $state = Ground;

        my sub drain() {
            $supplier.emit($_) for @partial;
            @partial = ();
        }

        my sub try-convert() {
            @partial = ($_,) with %special-keys{@partial.join};
            drain;
            $state = Ground;
        }

        whenever $in-supply -> $in {
            given $state {
                when Ground {
                    given $in {
                        when "\e" { @partial = $in,; $state = Escape }
                        default   { $supplier.emit($in) }
                    }
                }
                when Escape {
                    drain if $in eq "\e";
                    @partial.push: $in;

                    given $in {
                        when "\e"          { }
                        when any < ? O [ > { $state = Intermediate }
                        when 'A'..'D'      { try-convert }
                        when 'P'..'S'      { try-convert }
                        default            { drain; $state = Ground }
                    }
                }
                when Intermediate {
                    drain if $in eq "\e";
                    @partial.push: $in;

                    given $in {
                        when "\e"      { $state = Escape }
                        when ';'       { }
                        when '0'..'9'  { }
                        when 'A'..'Z'  { try-convert }
                        when 'a'..'z'  { try-convert }
                        when '~'       { try-convert }
                        when ' '       { try-convert }
                        default        { drain; $state = Ground }
                    }
                }
            }
        }
    }

    $supplier.Supply.on-close: { $in-supply.done }
}


#| Convert an input stream into a Supply of characters and special key events
multi sub decoded-input-supply(IO::Handle $input = $*IN) is export {
    decoded-input-supply(raw-input-supply($*IN))
}