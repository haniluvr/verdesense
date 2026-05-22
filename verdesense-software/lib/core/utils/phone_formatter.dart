import 'package:flutter/services.dart';

class PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // 1. Force the +63 prefix at all times
    if (text.length < 4 || !text.startsWith('+63 ')) {
      text = '+63 ';
    }

    // 2. Extract only digits following the '+63 ' prefix
    String prefix = '+63 ';
    String digitsOnly = text.substring(prefix.length).replaceAll(RegExp(r'\D'), '');

    // 3. Limit to 10 digits (Standard Philippine mobile number length after prefix)
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    // 4. Build the formatted string: +63 XXX XXX XXXX
    StringBuffer formatted = StringBuffer(prefix);
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        formatted.write(' ');
      }
      formatted.write(digitsOnly[i]);
    }

    String finalString = formatted.toString();

    // 5. Calculate cursor position
    int cursorPosition = newValue.selection.end;
    
    // If the user tried to delete the prefix, force cursor to end of prefix
    if (cursorPosition < prefix.length) {
      cursorPosition = prefix.length;
    }

    // Adjust cursor position based on spaces added
    // Simple approach for this fixed format: move to end if pasting or typing fast, 
    // or try to track it if editing in middle.
    // Given the strict format, usually moving to end is fine for phone numbers.
    // But let's try to be a bit smarter.
    
    // If we just added a character and it's a digit at a boundary, we might need to skip the space
    if (newValue.text.length > oldValue.text.length) {
       // Check if we just added a digit at index 3 or 6 relative to digitsOnly
       int digitIndex = cursorPosition - prefix.length;
       // If the digit we just added is followed by a space in the final string, 
       // and we were at that position, we should be past the space.
       // E.g. +63 921| type 5 -> +63 921 5|
       // In our loop, spaces are at indices 3 and 6 of digitsOnly.
       // Those correspond to indices 4+3=7 and 4+6=10 in finalString.
    }
    
    // For simplicity and to avoid bugs with cursor jumping, we'll use collapsed at end
    // for this specific UX since users usually type phone numbers from start to finish.
    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}
