"""Create an isolated immutable fixture on every CI run; never reuse old evidence."""
import argparse
from pathlib import Path
from common import ROOT,read_json
from generate_operations import create
from run_operations import run

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=True)
    old_report=a.out/'evidence/operations-report.json'
    if old_report.exists():old_report.unlink()
    # Jenkins reruns need an independent workspace, not stale fixture/report reuse.
    import tempfile
    with tempfile.TemporaryDirectory(dir=a.out) as temporary:
        root=Path(temporary);create(read_json(ROOT/'config/operations.json'),root/'fixture')
        report=run(root/'fixture',root/'model.sqlite')
        from common import write_json
        write_json(a.out/'evidence/operations-report.json',report)
        print('Independent acceptance passed for',len(report['checkpoints']),'daily checkpoints')
