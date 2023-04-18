import os
from subprocess import *
import re

if not os.path.isfile("edumips64-1.2.10.jar"):
    print("ERROR!!! edumips64-1.2.10.jar not found")
    exit(1)

login=input("Enter login: ")

def encypherLogin(login, encryptionKey):
    s=""
    for i, x in enumerate(login):
        if x in "0123456789":break
        if x in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":print("ERROR!!! Login should be lowercase")
        if i&1 == 0:
            offset = ord(encryptionKey[1])-ord("a")+1
        else:
            offset = -(ord(encryptionKey[2])-ord("a")+1)
        s+=chr((ord(x)-ord("a")+offset)%26+ord("a"))
    return s

def validateLogin(login):
    if(login[0] != "x"):
        print("ERROR!!! Login must start with x")
        exit(1)
    for x in login:
        if x in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
            print("ERROR!!! Login should be lowercase")
            exit(1)
        if x not in "0123456789abcdefghijklmnopqrstuvwxyz":
            print("ERROR!!! Login should contain only letters and numbers")
            exit(1)
    if not re.match(".*[0-9][0-9]$", login):
        print("ERROR!!! Login should end with two digits")
        exit(1)
    
validateLogin(login)
if not os.path.exists(login + ".s"):
    print(f"ERROR!!! File needs to be in same directory as file {login}.s")
    exit(1)

sourceCode = open(login + ".s", "r").read()
if f'login:          .asciiz "{login}"' not in sourceCode:
    print("ERROR!!! Login does not match the login in the source code")
    exit(1)

sourceCode = sourceCode.replace(f'login:          .asciiz "{login}"', f'login:          .asciiz "INSERT_LOGIN_HERE"')
sourceCode = sourceCode.replace("syscall 5", "daddi r30, r0, -16657")

def test(sourceCode, login, encryptionKey):
    print(f"LAUNCHING test with login {login}")
    sourceCode = sourceCode.replace("INSERT_LOGIN_HERE", login)
    open("temp_file_test.s", "w").write(sourceCode)
    p = Popen(["java", "-jar", "edumips64-1.2.10.jar", "-f", "temp_file_test.s", "-hl"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
    try:
        output, err = p.communicate(b"run\nshow symbols\nshow registers\nshow memory\nexit\n", timeout=10)
    except TimeoutExpired:
        print("ERROR!!! Timeout expired")
        return False
    output = output.decode("utf-8")
    if "The instruction belongs to WinMIPS64 instruction set, but it is not a legal MIPS64 instruction" in output:
        print("""ERROR!!! You are using one of instructions "BNEZ", "BEQZ", "HALT", "DADDUI", "DMULU", "L.D", "S.D", please replace them with something else.""")
        return False
    if "Register 30:\tFFFFFFFFFFFFBEEF" not in output:
        print("ERROR!!! Function print_string was not called")
        return False
    loginPos = int(re.findall("login: ([0-9]+)", output)[0])
    cipherPos = int(re.findall("cipher: ([0-9]+)", output)[0])
    data = re.findall("ADDRESS ([0-9A-F]+), VALUE ([0-9A-F]+)", output)
    data = [x[1] for x in data]
    data = "".join("".join(re.findall("..",  x)[::-1]) for x in data)

    loginString = data[loginPos*2:loginPos*2+2*len(login)]
    
    cipherLen = None
    for i, x in enumerate(login):
        if x in "0123456789":
            cipherLen = i
            break


    cipherString = data[cipherPos*2:cipherPos*2+2*cipherLen]

    loginString = "".join(chr(int(x, 16)) for x in re.findall("..", loginString))
    cipherString = "".join(chr(int(x, 16)) for x in re.findall("..", cipherString))

    isOk = True
    if loginString != login:
        print("ERROR!!! Login string is not correct")
        print(f"Expected: {login}, but found {loginString}")
        isOk = False

    if cipherString != encypherLogin(login, encryptionKey):
        print(len(cipherString), len(encypherLogin(login, encryptionKey)))
        print("ERROR!!! Cipher string is not correct")
        print(f"Expected: {encypherLogin(login, encryptionKey)}, but found {cipherString}")
        isOk = False
    
    if data[loginPos*2+2*len(login):loginPos*2+2*len(login)+2] != "00":
        print("ERROR!!! Missing null byte after login string")
        isOk = False

    if data[cipherPos*2+2*cipherLen:cipherPos*2+2*cipherLen+2] != "00":
        print("ERROR!!! Missing null byte after cipher string")
        isOk = False
    
    if isOk:
        print("TEST PASSED!!!")
    
    print()

    return isOk
    

tests = [
test(sourceCode, login, login),
test(sourceCode, "xlogin00", login),
test(sourceCode, "xlogin96", login),
test(sourceCode, "xlogin55", login),
test(sourceCode, "helloworld0", login),
test(sourceCode, "aaaaaaaaaaaa0", login),
test(sourceCode, "zzzzzzzzzzzz0", login),
test(sourceCode, "aaaaaaaaaaa0", login),
test(sourceCode, "zzzzzzzzzzz0", login),
test(sourceCode, "0", login),
test(sourceCode, "3", login),
test(sourceCode, "f8", login),
test(sourceCode, "ff9", login),
]

if os.path.exists("temp_file_test.s"):
    os.remove("temp_file_test.s")

print(f"SCORE: {sum(tests)}/{len(tests)}")

if sum(tests) == len(tests):
    print("ALL TESTS PASSED!!! YOU ARE AWESOME!!!")