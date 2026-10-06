# osc/crypto_utils.py

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend

def _pad(text):
    """Pads text to be a multiple of 8 bytes for DES."""
    n = len(text)
    padding_size = 8 - (n % 8)
    return text + bytes([padding_size] * padding_size)

def _unpad(padded_text):
    """Removes padding from text."""
    padding_size = padded_text[-1]
    return padded_text[:-padding_size]

def encrypt_string_des(input_string, key):
    """
    Encrypts a string using DES cipher in ECB mode for backward compatibility.

    Args:
        input_string (str): The string to encrypt.
        key (bytes): The 8-byte key for DES encryption.

    Returns:
        bytes: The encrypted data.
    """
    if len(key) != 8:
        raise ValueError("DES key must be 8 bytes long.")

    backend = default_backend()
    # Using ECB mode as it's common in legacy systems and pycrypto's default
    cipher = Cipher(algorithms.DES(key), mode=modes.ECB(), backend=backend)
    encryptor = cipher.encryptor()

    input_bytes = input_string.encode('utf-8')
    padded_bytes = _pad(input_bytes)

    encrypted = encryptor.update(padded_bytes) + encryptor.finalize()
    return encrypted

def decrypt_string_des(encrypted_data, key):
    """
    Decrypts data using DES cipher in ECB mode.

    Args:
        encrypted_data (bytes): The data to decrypt.
        key (bytes): The 8-byte key for DES decryption.

    Returns:
        str: The decrypted string.
    """
    if len(key) != 8:
        raise ValueError("DES key must be 8 bytes long.")

    backend = default_backend()
    cipher = Cipher(algorithms.DES(key), mode=modes.ECB(), backend=backend)
    decryptor = cipher.decryptor()

    decrypted_padded = decryptor.update(encrypted_data) + decryptor.finalize()
    decrypted_bytes = _unpad(decrypted_padded)
    
    return decrypted_bytes.decode('utf-8')
