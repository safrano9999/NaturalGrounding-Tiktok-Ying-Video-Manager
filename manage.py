#!/usr/bin/env python3
import sys
import argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / "functions"))

import manager
import presort
import playlist
import cleanup
import accounts
import core

def main():
    parser = argparse.ArgumentParser(description="NaturalGrounding Manager CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)
    
    sub.add_parser("download", help="Download new videos via yt-dlp")
    sub.add_parser("presort", help="Interactive presort queue via mpv")
    sub.add_parser("playlist", help="Manage and play playlists")
    sub.add_parser("cleanup", help="Run cleanup routines")
    sub.add_parser("clear-db", help="Truncate tables (DANGER)")
    sub.add_parser("health", help="Check system health")
    
    p_acc = sub.add_parser("accounts", help="Manage accounts")
    p_acc.add_argument("name", nargs="?", help="Account username")
    p_acc.add_argument("--blacklist", action="store_true")
    
    args = parser.parse_args()
    
    if args.cmd == "download":
        try:
            max_new = int(input("How many new videos per account? (default 2): ").strip() or 2)
            skip = int(input("Skip accounts with how many videos? (default 100): ").strip() or 100)
            manager.run_manager(max_new, skip)
        except KeyboardInterrupt:
            print("\nAborted.")
    elif args.cmd == "presort":
        presort.run_presort()
    elif args.cmd == "playlist":
        playlist.run_playlist()
    elif args.cmd == "cleanup":
        cleanup.run_cleanup()
    elif args.cmd == "clear-db":
        if input("Are you sure? (y/N): ").lower() == 'y':
            cleanup.clear_db()
    elif args.cmd == "health":
        from core import dashboard
        d = dashboard()
        print("Videos:", d['video_count'])
        print("JSONs:", d['json_count'])
        print("DB:", f"{d['db']['user']}@{d['db']['host']}:{d['db']['port']}/{d['db']['name']}")
        stats = accounts.get_stats()
        print("Accounts:", stats)
    elif args.cmd == "accounts":
        if args.name:
            print(accounts.process_account(args.name, 0 if args.blacklist else 1))
        else:
            print("Stats:", accounts.get_stats())
            print("Enter names to process (q to quit):")
            while True:
                name = input("> ").strip()
                if name == 'q': break
                if name:
                    print(accounts.process_account(name, 0 if args.blacklist else 1))

if __name__ == "__main__":
    main()
