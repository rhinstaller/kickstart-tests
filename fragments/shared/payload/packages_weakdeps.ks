# Install gnupg2 and make sure the packages it recommends are skipped
%packages --exclude-weakdeps
gnupg2
%end
