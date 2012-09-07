Simple ruby script to download all images from a given url

Looks for all images on a page by pattern - path and extension

Uses only Net::HTTP and URI modules, built in ruby STDLIB

Sometimes images may be just metioned in text (like 1.jpg), they will be treated as relative to current page, and if not exist (with is probably the case) will return 404 errors

TODO: add tests