import numpy as np
import sys

def verify_laplacian_limit():
    N = 157
    D_all = set(range(1, N)) # Объединение зон 13 + 60 + 84 дает весь Z_157 \ {0}
    
    lambda_cont_limit = len(D_all)  # N - 1 = 156
    expected_delta = 1.0 / N
    failed = False
    
    print(f"Verifying N={N}, Cont limit={lambda_cont_limit}, Theoretical Delta={expected_delta*100:.4f}%\n" + "-"*50)
    
    for omega in [1, 2, 5, 10, 50]: # Тестовые макроскопические моды
        lambda_disc = 2.0 * sum(np.sin(np.pi * omega * a / N)**2 for a in D_all)
        delta_computed = abs(lambda_disc - lambda_cont_limit) / lambda_disc
        
        err = "[FAIL]" if abs(delta_computed - expected_delta) > 1e-7 else "[OK]"
        if err == "[FAIL]": failed = True
        
        print(f"Mode {omega:2d} | Disc: {lambda_disc:.1f} | Delta: {delta_computed*100:.4f}% {err}")
        
    print("-"*50)
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    verify_laplacian_limit()
