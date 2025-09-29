#!/usr/bin/env bash

# invoked by release workflow
# (via https://github.com/bazel-contrib/.github/blob/master/.github/workflows/release_ruleset.yaml)

set -o errexit -o nounset -o pipefail

TAG="${GITHUB_REF_NAME}"
PREFIX="rules_multitool-${TAG:1}"
ARCHIVE="rules_multitool-${TAG:1}.tar.gz"

# embed version in MODULE.bazel
perl -pi -e "s/version = \"0\.0\.0\",/version = \"${TAG:1}\",/g" MODULE.bazel

stash_name=`git stash create`;
git archive --format=tar --prefix=${PREFIX}/ "${stash_name}" | gzip > $ARCHIVE

SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

# Add generated API docs to the release, see https://github.com/bazelbuild/bazel-central-registry/issues/5593
docs="$(mktemp -d)"; targets="$(mktemp)"
bazel --output_base="$docs" query --output=label --output_file="$targets" 'kind("starlark_doc_extract rule", //...)'
bazel --output_base="$docs" build --target_pattern_file="$targets" --remote_download_regex='.*doc_extract\.binaryproto'
tar --create --auto-compress \
    --directory "$(bazel --output_base="$docs" info bazel-bin)" \
    --file "$GITHUB_WORKSPACE/${ARCHIVE%.tar.gz}.docs.tar.gz" .

cat << EOF
## Using Bzlmod with Bazel 6

1. Enable with \`common --enable_bzlmod\` in \`.bazelrc\`.
2. Add to your \`MODULE.bazel\` file:

\`\`\`starlark
bazel_dep(name = "rules_multitool", version = "${TAG:1}")
\`\`\`
EOF
