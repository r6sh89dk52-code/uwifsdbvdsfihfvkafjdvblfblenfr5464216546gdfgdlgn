import os,subprocess,sys,tempfile,unittest
from pathlib import Path


class UIInventoryIntegrationTests(unittest.TestCase):
    """Run the real shell's discovery and final guard without launching Xcode."""
    root=Path(__file__).resolve().parents[3]

    def setUp(self):
        temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
        self.folder=Path(temporary.name)
        script=(self.root/'scripts/glass-audit/validate-macos.sh').read_text()
        program=script.split("python3 - <<'PY' > \"$OUT/ui-classes.tsv\"\n",1)[1].split('\nPY\n',1)[0]
        self.inventory=subprocess.check_output([sys.executable,'-c',program],cwd=self.root,text=True)
        self.guard=script.split('done < "$OUT/ui-classes.tsv"\n',1)[1].split('\ntest "$overall" = 0\n',1)[0]

    def run_guard(self,text):
        (self.folder/'ui-classes.tsv').write_text(text)
        return subprocess.run(['bash','-e','-c',self.guard],cwd=self.root,
            env={**os.environ,'OUT':str(self.folder)},capture_output=True,text=True)

    def test_current_complete_inventory_is_accepted_by_actual_shell_guard(self):
        result=self.run_guard(self.inventory)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_old_thirteen_case_inventory_is_rejected(self):
        rows=self.inventory.splitlines()
        for i,row in enumerate(rows):
            fields=row.split('\t')
            if fields[0]=='N2BiometricInteractionTests':
                self.assertEqual(fields[1],'2');fields[1]='1';rows[i]='\t'.join(fields);break
        else:self.fail('Biometric suite missing from real source discovery')
        self.assertNotEqual(self.run_guard('\n'.join(rows)+'\n').returncode,0)

    def test_duplicate_suite_cannot_fake_complete_total(self):
        rows=self.inventory.splitlines()
        one_case=[i for i,r in enumerate(rows) if r.split('\t')[1]=='1']
        self.assertGreaterEqual(len(one_case),2)
        rows[one_case[1]]=rows[one_case[0]]
        self.assertNotEqual(self.run_guard('\n'.join(rows)+'\n').returncode,0)

    def test_wrong_selected_class_cannot_fake_complete_counts(self):
        rows=self.inventory.splitlines();fields=rows[0].split('\t')
        fields[2]='UnrelatedTests';rows[0]='\t'.join(fields)
        self.assertNotEqual(self.run_guard('\n'.join(rows)+'\n').returncode,0)


if __name__=='__main__':unittest.main()
