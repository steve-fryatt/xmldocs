XML Docs
========

Generate documentation from XML sources.


Introduction
------------

XML Docs is a tool to generate documentation, primarily of a programmers' nature for the RISC OS platform, from XML sources. The primary target is the home-brew CMS used on my website, meaning that its use is a little specialised, but it is made available so as to provide a basis to work from for anyone who wishes to use the XML documentation in other contexts.


Use
---

XML Docs is written in Perl, and is intended for use on a Linux platform. On Ubuntu, or probably other Debian-based distributions, it requires the following packages to be installed:

- libfile-find-rule-perl
- libimage-magick-perl
- libxml-libxml-perl
- source-highlight

The **xmldoc.pl** tool can then be called from the command line, with the following parameters:

- --source &lt;file&gt; -- The root XML file for the document.
- --output &lt;folder&gt; -- The folder into which the output will be written.
- --php &lt;path&gt; -- The folder, specified relative to the output path, into which the PHP page files will be written.
- --image &lt;path&gt; -- The folder, specified relative to the output path, into which the image files will be written.
- --download &lt;path&gt; -- The folder, specified relative to the output path, into which the download archives will be written.
- --cms &lt;path&gt; -- The file, specified relative to the output path, into which the CMS page map will be written.
- --linkprefix &lt;prefix&gt; -- The URI prefix used for all relative page links.
- --imageprefix &lt;prefix&gt; -- The URI prefix used for all relative image links.
- --downloadprefix &lt;prefix&gt; -- The URI prefix used for all relative download links.


Licence
-------

XML Docs is licensed under the EUPL, Version 1.2 only (the "Licence"); you may not use this work except in compliance with the Licence.

You may obtain a copy of the Licence at <http://joinup.ec.europa.eu/software/page/eupl>.

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "**as is**"; basis, **without warranties or conditions of any kind**, either express or implied.

See the Licence for the specific language governing permissions and limitations under the Licence.