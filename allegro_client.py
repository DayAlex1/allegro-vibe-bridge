import os
import sys
import time
import argparse

# Config
WORKSPACE_DIR = os.path.join(os.path.dirname(__file__), "workspace")
IN_FILE = os.path.join(WORKSPACE_DIR, "vibe_in.il")
OUT_FILE = os.path.join(WORKSPACE_DIR, "vibe_out.log")

def send_code_to_allegro(code: str, timeout: int = 10):
    """
    Sends SKILL code to Allegro and waits for the result.
    """
    # 1. Setup workspace
    os.makedirs(WORKSPACE_DIR, exist_ok=True)
    
    # 2. Clean previous output
    if os.path.exists(OUT_FILE):
        try:
            os.remove(OUT_FILE)
        except OSError:
            pass # File might be locked, but typically shouldn't be

    # 3. Write code to input file
    print("\n[Antigravity] Sending code to Allegro...", flush=True)
    with open(IN_FILE, "w", encoding="utf-8") as f:
        f.write(code)

    # 4. Wait for output
    start_time = time.time()
    while time.time() - start_time < timeout:
        if os.path.exists(OUT_FILE):
            # Small delay to ensure Allegro finished writing
            time.sleep(0.1)
            try:
                with open(OUT_FILE, "r", encoding="utf-8") as f:
                    result = f.read().strip()
                
                print("[Allegro Response]")
                if result.startswith("SUCCESS"):
                    print(f"\033[92m{result}\033[0m") # Green
                else:
                    print(f"\033[91m{result}\033[0m") # Red
                return
            except Exception as e:
                print(f"[Antigravity Error] Could not read output: {e}")
                return
        
        # Poll interval
        time.sleep(0.2)
        
    print(f"\033[93m[Timeout] No response from Allegro within {timeout} seconds.\033[0m")
    print("Please check if vibeStartServer() is running in Allegro.")

def interactive_mode():
    print("========================================")
    print("  Allegro Vibe Coding Interactive Mode  ")
    print("========================================")
    print("Type your SKILL code. Press Enter to evaluate.")
    print("Type 'exit' or 'quit' to stop.")
    
    while True:
        try:
            code = input("\nSKILL> ")
            if code.strip().lower() in ['exit', 'quit']:
                break
            if code.strip():
                send_code_to_allegro(code)
        except KeyboardInterrupt:
            break
        except EOFError:
            break

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send SKILL code to Allegro")
    parser.add_argument("code", nargs="*", help="SKILL code to execute")
    parser.add_argument("-f", "--file", help="Path to a SKILL (.il) file to read and execute")
    args = parser.parse_args()
    
    if args.file:
        if os.path.exists(args.file):
            with open(args.file, "r", encoding="utf-8") as f:
                code_str = f.read()
            send_code_to_allegro(code_str)
        else:
            print(f"Error: File '{args.file}' not found.")
    elif args.code:
        code_str = " ".join(args.code)
        send_code_to_allegro(code_str)
    else:
        interactive_mode()
