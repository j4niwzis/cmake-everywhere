# What the kernel promises a program, as headers.
#
# The C library stops at the system call boundary: everything on the other
# side of it -- the constants a program passes to ioctl, the structures the
# graphics drivers exchange with the kernel, the limits in linux/limits.h --
# is described by the kernel's own headers, and a distribution installs them
# beside the C library's.
#
# A build that carries its own C library has to carry these too, and the
# kernel's tree is not the place to take them from: it is two hundred
# megabytes and its headers have to be sanitised before a program may
# include them. This is that sanitising, done once and published: the same
# set every musl toolchain is built with.
#
# Sources only. What installs them is whoever assembles the toolchain, which
# knows which architecture it is for.
cme_declare_port(
  NAME kernel-headers
  PROVIDES kernel-headers
  VERSION 4.19.88-2
  SOURCE_ONLY YES
  LICENSE GPL-2.0-only-WITH-Linux-syscall-note
  URL "https://github.com/sabotage-linux/kernel-headers/archive/refs/tags/v4.19.88-2.tar.gz"
  URL_HASH "SHA256=16161844e56944d39794ad74c2dfd6faad12bda79b5dc00595f4178d28a92e2d"
)

function(cme_adapt_kernel-headers source binary)
  cme_export_variable(kernel-headers KERNEL_HEADERS_DIR "${source}")
  cme_export_variable(kernel-headers KERNEL_HEADERS_FOUND TRUE)
endfunction()
