#!/bin/sh -efu
# Copyright (c) 2018 Dmitry V. Levin <ldv@strace.io>
# Copyright (c) 2018-2022 The strace developers.
# All rights reserved.
#
# SPDX-License-Identifier: LGPL-2.1-or-later

[ "x${D:-0}" != x1 ] || set -x

input="$1"
shift

cat <<EOF
/* Generated by $0 from $input; do not edit. */
#include "defs.h"
#ifdef HAVE_LINUX_BPF_H
# include <linux/bpf.h>
# include "bpf_attr.h"
# include "static_assert.h"

EOF

for struct in $(sed -n 's/^struct \([^[:space:]]\+_struct\) .*/\1/p' < "$input"); do
	case "$struct" in
		BPF_*) type_name='union bpf_attr' ;;
		*) type_name="struct ${struct%_struct}" ;;
	esac
	TYPE_NAME="$(printf %s "$type_name" |tr '[:lower:] ' '[:upper:]_')"

	enum="$(sed -n 's/^struct '"$struct"' \/\* \([^[:space:]]\+\) \*\/ {.*/\1/p' < "$input")"
	ENUM="$(printf %s "$enum" |tr '[:lower:]' '[:upper:]')"
	enum="$enum${enum:+.}"
	ENUM="$ENUM${ENUM:+_}"
	sed -n '/^struct '"$struct"' [^{]*{/,/^};$/p' < "$input" |
	sed -n 's/^[[:space:]]\+[^][;:]*[[:space:]]\([^]}[[:space:];:]\+\)\(\[[^;:]*\]\)\?;$/\1/p' |
	while read field; do
		FIELD="$(printf %s "$field" |tr '[:lower:]' '[:upper:]')"
		cat <<EOF

# ifdef HAVE_${TYPE_NAME}_$ENUM$FIELD
	static_assert(sizeof_field(struct $struct, $field) == sizeof_field($type_name, $enum$field),
		      "$struct.$field size mismatch");
	static_assert(offsetof(struct $struct, $field) == offsetof($type_name, $enum$field),
		      "$struct.$field offset mismatch");
# endif /* HAVE_${TYPE_NAME}_$ENUM$FIELD */
EOF
	done
		cat <<EOF

static_assert(${struct}_size == expected_${struct}_size,
	      "${struct}_size mismatch");
EOF

done

cat <<'EOF'

#endif /* HAVE_LINUX_BPF_H */
EOF
