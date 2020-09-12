# Podcast Download

This project provide a script to download all podcast files & image if any from rss xml file

use `./sync-podcast.sh -h` for more infos.

```
USAGE : ./sync-podcast.sh [OPTIONS]

WHERE OPTIONS are :

	-o|--output-dir)         : define output directory (default is 'podcasts' in current folder)
	-h|--help)               : print this message and exist without error
	-f|--filter)             : this option allow to build only podcatst with title matching given {filter} regex (else, all rss urls will be build)
	-c|--config-file)        : specify CONFIG_FILE path instead default one (if found, this file may set default options like RSS_URL ...)\ndefault path is {output-dir}/config
	-y|--force-yes)          : run script without interactions/confirmations
	-d|--debug)              : option display information about building process
	-u|--url)                : specify url which to dowload rss.xml (use --reload-xml to refresh an existing rss.xml file)
	-B|--rebuild-urls)       : this option allow to replace existing urls.txt previously built with new rss.xml file or new filter
	-R|--reload-xml)         : this option allow to replace existing rss.xml previously downloaded
```
