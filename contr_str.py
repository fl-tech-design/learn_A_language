def let_uppercase_first(str_small: str) -> str:
    """
    Converts the first character of a string to uppercase.

    Args:
        str_small (str): The input string with the first character in lowercase.

    Returns:
        str: The string with the first character converted to uppercase.
    """
    txt = str_small
    new_txt = txt[0].upper() + txt[1:]
    return new_txt
