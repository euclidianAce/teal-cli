#!/usr/bin/env sh

echo -e "\e[1;32mBuilding with tl...\e[0m" && tl -q build && \
	echo -e "\e[1;32mBuilding with tlc via tl compiled code\e[0m" && ./bin/tlc build -qu && \
	rm -r build/tlcli && \
	echo -e "\e[1;32mReplacing tl compiled code with tlc compiled code\e[0m" && mv tmp/build build/tlcli && \
	rm -r tmp && \
	echo -e "\e[1;32mBuilding with tlc via tlc compiled code\e[0m" && ./bin/tlc build -qu && \
	echo -e "\e[1;32mBootstrapping successful\e[0m" || echo -e "\e[1;31mBootstrapping unsuccessful\e[0m"
