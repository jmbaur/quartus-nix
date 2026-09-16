# shellcheck shell=bash

quartusNormalizeSof() {
	local sof
	while IFS= read -r -d "" sof; do
		echo "normalizing sof build timestamp: $sof"
		@normalizeSof@ "$sof"
	done < <(find "$prefix" -type f -name '*.sof' -print0)
}

# Removes timestamps from summary files, for example:
# ```
# Fitter Status : Successful - Fri Jun 28 11:57:02 2024
# ```
quartusNormalizeSummary() {
	local summary stamp
	stamp=$(date --utc --date="@$SOURCE_DATE_EPOCH" '+%a %b %e %H:%M:%S %Y')
	while IFS= read -r -d "" summary; do
		echo "normalizing summary build timestamp: $summary"
		sed -i -E \
			"s/^(.*Status : .*) - [A-Z][a-z]{2} [A-Z][a-z]{2} [ 0-9][0-9] [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}$/\1 - $stamp/" \
			"$summary"
	done < <(find "$prefix" -type f -name '*.summary' -print0)
}

if [ -z "${dontFixupQuartusArtifacts-}" ]; then
	echo "Using quartusNormalizeSof and quartusNormalizeSummary hooks"
	fixupOutputHooks+=(quartusNormalizeSof quartusNormalizeSummary)
fi
