from build.ab import normalrule
from tools.build import mkcpmfs, img2osi
from build.llvm import llvmrawprogram, llvmclibrary
from config import (
    MINIMAL_APPS,
    MINIMAL_APPS_SRCS,
    BIG_APPS,
    BIG_APPS_SRCS,
    SCREEN_APPS,
    SCREEN_APPS_SRCS,
    PASCAL_APPS,
)

llvmrawprogram(
    name="osi500_bios",
    srcs=["./osi.S"],
    deps=["include", "src/lib+bioslib"],
    cflags=["-DOSI500"],
    linkscript="./osi.ld",
)

llvmrawprogram(
    name="osi600_bios",
    srcs=["./osi.S"],
    deps=["include", "src/lib+bioslib"],
    cflags=["-DOSI600"],
    linkscript="./osi.ld",
)

mkcpmfs(
    name="osi500_rawdiskimage",
    format="osi5",
    bootimage=".+osi500_bios",
    size=128 * 640,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
    }
    | MINIMAL_APPS
)

mkcpmfs(
    name="osi600_rawdiskimage",
    format="osi5",
    bootimage=".+osi600_bios",
    size=128 * 640,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
    }
    | MINIMAL_APPS
)

img2osi(
    name="osi500_diskimage",
    src=".+osi500_rawdiskimage",
)

img2osi(
    name="osi600_diskimage",
    src=".+osi600_rawdiskimage",
)
