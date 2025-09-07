event_dirs ?= $(shell find data/events -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
event_category_files := $(foreach dir,$(event_dirs),$(dir)/categories.txt)

.SECONDARY:

all: clean data/events
	make brackets

.PHONY: clean
clean:
	@rm -rf data/events
	@mkdir -p data/events

data/events/past.events.json: always
	@mkdir -p data
	@curl -s -X POST https://www.jjworldleague.com/ajax/new_load_events.php \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "type=past&age=1" > $@

data/events/next.events.json: always
	@mkdir -p data
	@curl -s -X POST https://www.jjworldleague.com/ajax/new_load_events.php \
		-H "Content-Type: application/x-www-form-urlencoded" \
		-d "type=next&age=1" > $@

.PHONY: data/events
data/events: data/events/next.events.json data/events/past.events.json
	@mkdir -p $@
	@jq -c -s 'add | map({name: .name, urlfriendly: .urlfriendly})[]' $^ | \
	while read -r ev; do \
		url=$$(echo $$ev | jq -r .urlfriendly); \
		name=$$(echo $$ev | jq -r .name); \
		dir=$@/$$url; \
		mkdir -p $$dir; \
		echo "$$name" > $$dir/name.txt; \
	done

data/events/%/categories.txt:
	@echo "Fetching categories for event $*"
	@mkdir -p $(dir $@)
	@curl -s https://www.jjworldleague.com/events/$* | grep -o 'data-event_cat_id\s\+="[0-9]\+"' | sed 's/data-event_cat_id *= *"\([0-9]\+\)"/\1/' > $@

data/events/%/categories/brackets.make: data/events/%/categories.txt
	@echo "Fetching brackets for event $*"
	@mkdir -p $(dir $@)
	@while read -r catid; do \
		curl -s 'https://hermes.jjworldleague.com/endpoint2/brackets/get_json_ecat' \
			-H "Content-Type: application/x-www-form-urlencoded" \
			-d "event-cat-id=$$catid" | jq '.' >> $(dir $@)/$$(printf "%06d" $$catid).json; \
	done < $<

.PHONY: brackets
brackets: $(foreach dir,$(event_dirs),$(dir)/categories/brackets.make)
	@echo

.PHONY: always
always:
	@: true

