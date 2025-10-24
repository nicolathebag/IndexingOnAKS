from PyPDF2 import PdfReader

def convert_pdf_to_text(pdf_path):
    """
    Convert a PDF file to text.

    Args:
        pdf_path (str): The path to the PDF file.

    Returns:
        str: The extracted text from the PDF.
    """
    text = ""
    try:
        reader = PdfReader(pdf_path)
        for page in reader.pages:
            text += page.extract_text() + "\n"
    except Exception as e:
        print(f"Error reading {pdf_path}: {e}")
    
    return text

def save_text_to_file(text, output_path):
    """
    Save the extracted text to a file.

    Args:
        text (str): The text to save.
        output_path (str): The path to the output file.
    """
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(text)
    except Exception as e:
        print(f"Error writing to {output_path}: {e}")