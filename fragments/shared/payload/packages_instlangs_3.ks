# Install a short list of languages
# Use ones with translations in blivet to make them easy to find.
# Add glibc-all-langpacks to install locale data separately from
# lang --addsupport.
%packages --inst-langs=es:fr:it
python3-blivet
glibc-all-langpacks
%end
