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
    name="osi400mf_bios",
    srcs=["./osi.S"],
    deps=["include",
          "src/lib+bioslib",
          "src/arch/osi/floppy.S",
          "src/arch/osi/ascii.S"],
    cflags=["-DOSI400"],
    linkscript="./osi.ld",
)

llvmrawprogram(
    name="osi500mf_bios",
    srcs=["./osi.S"],
    deps=["include",
          "src/lib+bioslib",
          "src/arch/osi/floppy.S",
          "src/arch/osi/keyboard.S"],
    cflags=["-DOSI500"],
    linkscript="./osi.ld",
)

llvmrawprogram(
    name="osi600mf_bios",
    srcs=["./osi.S"],
    deps=["include",
          "src/lib+bioslib",
          "src/arch/osi/floppy.S",
          "src/arch/osi/keyboard.S"],
    cflags=["-DOSI600"],
    linkscript="./osi.ld",
)

mkcpmfs(
    name="osi400mf_rawdiskimage",
    format="osi5",
    bootimage=".+osi400mf_bios",
    size=128 * 640,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
    }
    | MINIMAL_APPS
)

mkcpmfs(
    name="osi500mf_rawdiskimage",
    format="osi5",
    bootimage=".+osi500mf_bios",
    size=128 * 640,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
    }
    | MINIMAL_APPS
)

mkcpmfs(
    name="osi600mf_rawdiskimage",
    format="osi5",
    bootimage=".+osi600mf_bios",
    size=128 * 640,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
    }
    | MINIMAL_APPS
)

mkcpmfs(
    name="osimf-b_rawdiskimage",
    format="osi5",
    size=128 * 640,
    items={
    }
    | BIG_APPS
    | PASCAL_APPS
)

mkcpmfs(
    name="osimf-c_rawdiskimage",
    format="osi5",
    size=128 * 640,
    items={
    }
    | MINIMAL_APPS_SRCS
    | BIG_APPS_SRCS
)

mkcpmfs(
    name="osimf-d_rawdiskimage",
    format="osi5",
    size=128 * 640,
    items={
    }
)

img2osi(
    name="osi400mf_diskimage",
    src=".+osi400mf_rawdiskimage",
)

img2osi(
    name="osi500mf_diskimage",
    src=".+osi500mf_rawdiskimage",
)

img2osi(
    name="osi600mf_diskimage",
    src=".+osi600mf_rawdiskimage",
)

img2osi(
    name="osimf-b_diskimage",
    src=".+osimf-b_rawdiskimage",
)

img2osi(
    name="osimf-c_diskimage",
    src=".+osimf-c_rawdiskimage",
)

img2osi(
    name="osimf-d_diskimage",
    src=".+osimf-d_rawdiskimage",
)
