Building Notes
==============

Prerequisites:
- Apple Developer Tools
- sope-xml
- sope-core

There are two ways to build SOPE on MacOSX, either using the gnustep-make
package or as native Xcode projects. The first option is usually used when
you build SOPE for use with OGo, while the latter is more appropriate for
SOPE:X applications.

Building using gstep-make:
==========================

First install gnustep-make (eg v1.8), then ensure that GNUstep.sh is properly
sources. For the build just enter:
  make -s install
or
  make -s debug=yes install
if you build with debug informations.

Building using Xcode:
=====================

The Xcode build comes in two variants, one for development and the other for
deployment.


Development
-----------
Development usually means you're happily hacking away at your pet
projects and sometimes want to update the SOPE frameworks. For this purpose
use the "all" target and the accompanied "Development" build style. Later,
you can narrow the target down to something more specific. For development we
assume the destination for frameworks to be /Library/Frameworks. Once you are
done building all the frameworks the loader commands of the frameworks will
have that destination path built in. In order to use the frameworks you either
have to install them (by copying them manually to their destination) or to
prepare symlinks from /Library/Frameworks to the place where the built products
are. I usually build everything in a central place (i.e. /Local/BuildArea) and
have symlinks from /Library/Frameworks to /Local/BuildArea for each of the
products.

Also the following products are expected to be in the following locations:
*.sax -> /Library/SaxDrivers
*.sxp -> /Library/SoProducts

Either copy them to the appropriate places or symlink them (my suggestion).


Deployment
----------
Deployment in our terms means you want to copy all required SOPE products into
an application's app wrapper. For this step all frameworks need to be built in
a special fashion, as the "install_name" of the frameworks needs to be prepared
to point to a relative path in the app wrapper. The situation is even more
complicated as all frameworks during linking store the "install names" of other
frameworks in their mach loader commands. In order for this step not to break
we need to set up an environment which is clearly separated from the
Development environment. I chose to use $(USER_LIBRARY_DIR)/EmbeddedFrameworks
as the default destination for these builds. In order for your application to
easily pick up the built products and copy them into its app wrapper this
location needs to be fixed and easily accessible. Note that on my system
~/Library/EmbeddedFrameworks is a symlink to /Library/EmbeddedFrameworks so
even if you don't like the location at all it's very easy to point it to 
somewhere else. As soon as you have set this up you can use the
"Wrapper Contents" target with the accompanied "Wrapper" build style to build
all wrapper contents in the appropriate fashion. When you're done you can copy
all the wrapper products into your application's wrapper. The expected
destination is the "Frameworks" directory in the wrappers "Contents" directory.
For a complete list of what you need to copy into your application's wrapper
see the "Direct Dependencies" of all "Wrapper Contents" targets in all SOPE
related projects. At the time of this writing the complete list for SOPE
consisted of the following:

sope-ical
  NGiCal.framework


Note: "A word on umbrellas"
      The general idea of umbrellas is to make life easier by providing a cover
      for linking. In an ideal world we would provide a SOPE umbrella (we 
      actually do that) and you just link against that and forget about the
      complete list. However, with the "Wrapper" style things do not work that
      way. Because the "install name"s of all frameworks are relative paths,
      during linking the mach dyld cannot find the dependend frameworks
      (because the path isn't absolute) and thus symbol checking fails. This
      directly leads to prebinding to fail which we really don't want since we
      have such a huge dependency tree and prebinding escpecially in our case
      speeds up loading significantly. So, umbrellas do not really help with
      "Wrapper" products - in fact they just add to the overall dependency
      graph without providing any benefit. With the notable exception of the
      "Development" build style umbrellas are totally useless. If you're
      not planning to do a "Wrapper" deployment you might be happy to have
      the umbrellas, however, that's why they are still here.

Note: You cannot use the -buildAllTargets commandline argument for Xcode,
      because the Xcode projects also contain a target to build in the
      gstep-make environment (called GSM:all)


Prebinding Notes
================

General technical information about prebinding is available from Apple at
http://developer.apple.com/documentation/Performance/Conceptual/LaunchTime/Tasks/Prebinding.html#//apple_ref/doc/uid/20001858.

OGo frameworks currently use the range from 0xC0000000 to 0xCFFFFFFF.

Any questions and feedback regarding our use of this range should go to
Marcus Müller <znek@mulle-kybernetik.com>.


SxCore: 0xC1000000 - 0xC2FFFFFF
===============================

0xC1E00000 NGiCal
