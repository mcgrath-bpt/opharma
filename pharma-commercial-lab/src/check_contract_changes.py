"""Jenkins PR compatibility check; missing previous ODCS is initial adoption."""
import os
import subprocess
import json
from odcs import registry,check_evolution,LAYERS

def run():
    current=registry();target=os.environ.get('CHANGE_TARGET')
    if not target:
        print('ODCS valid; no PR target provided for evolution comparison');return
    # Work both as a standalone repository and in the opharma subdirectory.
    prefix=subprocess.run(['git','rev-parse','--show-prefix'],capture_output=True,text=True,check=True).stdout.strip()
    # argv avoids shell interpolation of branch names.
    for layer in LAYERS:
        result=subprocess.run(['git','show','origin/'+target+':'+prefix+'contracts/odcs/'+layer+'.odcs.json'],capture_output=True,text=True)
        if result.returncode:
            exists=subprocess.run(['git','rev-parse','--verify','origin/'+target],capture_output=True)
            if exists.returncode:raise ValueError('PR target is not fetched; evolution check cannot proceed')
            print(layer+': initial ODCS adoption');continue
        check_evolution(json.loads(result.stdout),current[layer]);print(layer+': compatible or explicitly major-versioned')

if __name__=='__main__':run()
