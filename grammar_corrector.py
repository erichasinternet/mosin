
import sys
from transformers import T5ForConditionalGeneration, T5Tokenizer

def correct_grammar(text):
    # Handle empty or whitespace-only input
    if not text or not text.strip():
        return text
    
    model_name = "/Users/eric/mosin/models/flan-t5-grammar-p100"
    tokenizer = T5Tokenizer.from_pretrained(model_name)
    model = T5ForConditionalGeneration.from_pretrained(model_name)

    prefixed_text = "correct grammar: " + text
    input_ids = tokenizer.encode(prefixed_text, return_tensors="pt")

    outputs = model.generate(input_ids, max_length=256)
    corrected_text = tokenizer.decode(outputs[0], skip_special_tokens=True)

    return corrected_text

if __name__ == "__main__":
    input_text = sys.argv[1]
    corrected = correct_grammar(input_text)
    print(corrected, flush=True)
