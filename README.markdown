QCMono
======

This Quartz Composer plugin uses the Mono development framework to provide scripting support using C# and other languages within the Quartz Composer compositions.

Installing
----------

Mono 2.8 or later must be installed to use this plugin.  Mono can be downloaded from 
	
	http://www.go-mono.com/mono-downloads/download.html

Note: the Mono 2.8 framework contains a broken symlink.  This will prevent XCode from building the QCMono plugin.  To correct the problem,
replace the broken 'Mono' symlink in /Library/Frameworks/Mono.framework/ with a new symlink pointing to /Library/Frameworks/Mono.framework/Versions/Current/lib/libmono-2.0.dylib

License
-------

Copyright (c) 2010 Caleb Cannon

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.

Additional Sources
------------------

* LineNumberingTextView by Koen van der Drift - http://home.earthlink.net/~kvddrift/software/
* KSyntaxColoredTextDocument by Uli Kusterer - http://github.com/uliwitness/UKSyntaxColoredTextDocument

Contact Information
-------------------

Get the latest version of QCMono at

http://github.com/calebcannon/QCMono

E-Mail: caleb.cannon@gmail.com