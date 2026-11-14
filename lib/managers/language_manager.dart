/// Small helper – 1:1 from contr_str.py.
String letUppercaseFirst(String str) {
  if (str.isEmpty) return str;
  return str[0].toUpperCase() + str.substring(1);
}
