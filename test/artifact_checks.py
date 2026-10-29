"""Regression checks for provenance failures and interrupted-run summaries."""

import csv
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import artifact
import run_experiments


class ArtifactChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in ("lib", "bin", "test", "scripts", ".github", "results/representative"):
            (self.root / name).mkdir(parents=True)
        for name in ("dune-project", ".gitignore", ".gitattributes", "VERSION"):
            (self.root / name).write_text("review-1\n")
        (self.root / "lib/example.ml").write_text("let value = 1\n")
        self.result = self.root / "results/representative/raw.csv"
        self.result.write_text("status\ncomplete\n")
        sources = artifact.measurement_sources(self.root)
        record = {"source_sha256": sources, "source_snapshot_sha256": artifact.digest(sources),
                  "result_sha256": artifact.hashes([self.result], self.root)}
        for name in ("results/representative/metadata.json", "results/milestone-metadata.json"):
            (self.root / name).write_text(json.dumps(record))

    def test_changed_source_rejects_old_results(self):
        (self.root / "lib/example.ml").write_text("let value = 2\n")
        with self.assertRaisesRegex(ValueError, "measurement sources"):
            artifact.create_manifest(self.root)

    def test_added_source_rejects_old_results(self):
        (self.root / "lib/added.ml").write_text("let added = true\n")
        with self.assertRaisesRegex(ValueError, "measurement sources"):
            artifact.create_manifest(self.root)

    def test_changed_result_rejected(self):
        self.result.write_text("status\nstate_limit\n")
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            artifact.create_manifest(self.root)

    def test_source_line_endings_are_portable(self):
        original = artifact.measurement_sources(self.root)
        (self.root / "lib/example.ml").write_bytes(b"let value = 1\r\n")
        self.assertEqual(original, artifact.measurement_sources(self.root))

    def test_archive_is_repeatable_and_verifiable_after_extraction(self):
        artifact.package(self.root)
        archive = next((self.root / "artifacts").glob("*.zip"))
        first = hashlib.sha256(archive.read_bytes()).hexdigest()
        artifact.package(self.root)
        self.assertEqual(first, hashlib.sha256(archive.read_bytes()).hexdigest())
        extracted = self.root / "extracted"
        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(extracted)
        artifact.verify(extracted)
        (extracted / "README.md").write_text("Added after packaging\n")
        with self.assertRaisesRegex(ValueError, "manifest differs"):
            artifact.verify(extracted)

    def test_mixed_trials_do_not_count_as_complete_configuration(self):
        rows = [{"example": "example", "allocation": "pool4", "gc": "false", "status": status}
                for status in ("complete", "state_limit", "cpu_limit")]
        run_experiments.completion_table(rows, self.root)
        with (self.root / "completion.csv").open() as table:
            summary = next(csv.DictReader(table))
        self.assertEqual(summary["complete_configurations"], "0")
        self.assertEqual(summary["complete_trials"], "1")
        self.assertEqual(summary["state_limit_trials"], "1")
        self.assertEqual(summary["cpu_limit_trials"], "1")


if __name__ == "__main__":
    unittest.main()
