#!/usr/bin/env python

import argparse
import re
from pathlib import Path
from dataclasses import dataclass

# ignored services
IGNORED = ["ActivityManager", "PackageManager", "WindowManager", "Resources", "JobStore", "AlarmManager", "WifiManager", "ImsRcsService", "QImsService", "ImsService"]
ALWAYS = ["QC_RIL_OEM_HOOK", "qcril"]


@dataclass
class SourceLine:
    nr: int
    path: str
    code: str

class SourceFile:
    def __init__(self, path):
        self.path = path
        self.log = []
        self.index = set()
        self._load()

    def _load(self):
        nr = 0
        for line in open(self.path, 'r'):
            nr += 1
            line = line.strip()
            for word in line.split():
                word = word.strip(',=";()')
                self.index.add(word)
            if line.lower().find("log") >= 0:
                self.log.append(SourceLine(nr=nr, path=self.path, code=line))

    def hit(self, service, message):
        if service not in self.index:
            return 0, None
        best_n = 0
        best_line = None
        keys = message.split()
        for line in self.log:
            n = 0
            for key in keys:
                key = key.strip(',=";()')
                if len(key) > 0 and line.code.find(key) >= 0:
                    n += 1
            if n > best_n:
                best_n = n
                best_line = line
        return best_n, best_line

class Sources:
    def __init__(self, pathdirname):
        pathdir = Path(pathdirname)
        self.sourcefiles = []
        for file in pathdir.rglob("*.java"):
            sf = SourceFile(file)
            if sf.log:
                self.sourcefiles.append(sf)

    def hit(self, service, message):
        best_n = 0
        best_line = None
        for src in self.sourcefiles:
            n, line = src.hit(service, message)
            if n > best_n:
                best_n = n
                best_line = line
        return best_n, best_line
  

def main():
    parser = argparse.ArgumentParser(description="Link logcat lines to source code")
    parser.add_argument("logcat", type=Path, help="Path to Android logcat file")
    parser.add_argument("sourcedir", type=Path, help="Path to Android source folder")
    args = parser.parse_args()

    # load sources
    sources = Sources(args.sourcedir)

    for logline in args.logcat.open():
        logline = logline.strip()
        linesplit = logline.split(maxsplit=6)
        if len(linesplit) > 6 and linesplit[5][-1] == ':':
            service = linesplit[5][:-1].strip()
            message = linesplit[6]
            if len(service) == 0 or service in IGNORED:
                continue
            n, line = sources.hit(service, message)
            if n > 1:
                print(f'%s --> %s:%d [%d]' % (logline, line.path, line.nr, n))
            elif n > 0:
                print(logline)
            else:
                for check in ALWAYS:
                    if logline.lower().find(check.lower()) >= 0:
                        print(logline)
                        break

            

if __name__ == "__main__":
    main()
