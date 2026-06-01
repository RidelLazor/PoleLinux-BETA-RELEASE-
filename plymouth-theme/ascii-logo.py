#!/usr/bin/env python3
"""PoleLinux ASCII logo."""

import shutil

LOGO = r"""
PPPPPPPPPPPPPPPP
P::::::::::::::PP
P::::PPPPPP:::::P
P::::P      P::::P
P::::P      P::::P
P::::PPPPPP:::::P
P:::::::::::::PP
P::::PPPPPPPPP
P::::P
P::::P
P::::P
P::::P
PPPPPP
"""

TITLE = r"""
PPPPPPPPPP    OOOOOOOOO     LL          EEEEEEEEEEEE
PP      PPP  OOO     OOO    LL          EE
PP      PPP OOO       OOO   LL          EE
PPPPPPPPPP  OOO       OOO   LL          EEEEEEE
PP          OOO       OOO   LL          EE
PP           OOO     OOO    LL          EE
PP            OOOOOOOOO     LLLLLLLLLL  EEEEEEEEEEEE

LL          IIIIIIII  NN      NN  UU      UU  XX      XX
LL            IIII    NNN     NN  UU      UU   XX    XX
LL            IIII    NN NN   NN  UU      UU    XX  XX
LL            IIII    NN  NN  NN  UU      UU     XXXX
LL            IIII    NN   NN NN  UU      UU     XXXX
LL            IIII    NN    NNNN   UU    UU     XX  XX
LLLLLLLLLL  IIIIIIII  NN      NN    UUUUUU     XX    XX
"""

SUBTITLE = r"""    1.0  --  Powered by Debian"""


def main():
    cols = shutil.get_terminal_size().columns
    for block in (LOGO, TITLE, SUBTITLE):
        for line in block.split("\n"):
            indent = max(0, (cols - len(line)) // 2)
            print(" " * indent + line)
        print()


if __name__ == "__main__":
    main()
