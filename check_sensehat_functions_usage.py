import ast

# List of Sense HAT functions to check for
SENSE_HAT_FUNCTIONS = ['set_pixel', 'set_pixels', 'load_image']

def check_sensehat_functions_usage(file_path):
    with open(file_path, 'r') as file:
        code = file.read()
    
    tree = ast.parse(code)

    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            if hasattr(node.func, 'id') and node.func.id in SENSE_HAT_FUNCTIONS:
                print(f"Error: '{node.func.id}' function from Sense HAT should not be used.")
                return False
    return True

file_path = "./main.py"
if not check_sensehat_functions_usage(file_path):
    print("Sense HAT functions set_pixel, set_pixels, or load_image found in the Python code.")
    exit 1
  
