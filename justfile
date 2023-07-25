
project := "https://github.com/thin-edge/thin-edge.io"

# Clean all build files
clean:
    rm -rf .docusaurus
    rm -rf node_modules
    rm -rf build
    rm -rf versioned_docs
    rm -rf versioned_sidebars
    rm -f versions.json

# Setup the project by adding symlinks to the thin-edge.io docs
init:
    test -e ../thin-edge.io || git clone {{project}} ../thin-edge.io
    ln -sf ../thin-edge.io/docs/src ./docs

# Checkout docs from the last official release
#
# Note: The versioned docs are not commited to the project
# they are only copied during build time. This is to reduce the 'noise'
# in the commit history.
# See the docs for more info: https://docusaurus.io/docs/versioning
checkout-version version="" branch="":
    #!/usr/bin/env bash
    set -euxo pipefail

    echo "Cloning latest official release"
    rm -rf ../thin-edge.io_versioned
    git clone {{project}} ../thin-edge.io_versioned

    TAG="{{version}}"
    if [ -z "$TAG" ]; then
        TAG="$(git -C ../thin-edge.io_versioned describe --tags $(git -C ../thin-edge.io_versioned rev-list --tags --max-count=1))"
    fi

    SOURCE_REPO_INFO=""
    if [ -n "{{branch}}" ]; then
        echo "Checking out a branch"
        git -C ../thin-edge.io_versioned checkout "{{branch}}"
        SOURCE_REPO_INFO="$(git -C ../thin-edge.io_versioned describe --always) {{branch}}"
    else
        echo "Checking out a tag"
        git -C ../thin-edge.io_versioned checkout "$TAG" -b "latest"
        SOURCE_REPO_INFO="$TAG"
    fi

    echo "Creating list of versions to be included (only 1 is supported atm)"
    printf '["%s"]' "$TAG"  > versions.json

    echo "Copying docs from $TAG"
    mkdir -p versioned_docs
    rm -rf "./versioned_docs/version-$TAG"
    # Symlinks are not supported here, so we have to copy the files
    cp -R ../thin-edge.io_versioned/docs/src "./versioned_docs/version-$TAG"

    # Store marker info about the source repo so it is easier to trace
    printf '%s' "$SOURCE_REPO_INFO" > "./versioned_docs/version-$TAG/.version"

    echo "Creating versioned sidebars"
    mkdir -p versioned_sidebars
    printf '{"tutorialSidebar": [{"type": "autogenerated", "dirName": "."}]}' > "versioned_sidebars/version-$TAG-sidebars.json"

# Install nodejs dependencies
install:
    yarn install

# Start a local dev server
docs: install
    yarn start

# Build production docs
build: install
    yarn build

# Run unit tests (to check custom plugins etc.)
test:
    yarn run test

# Serve production docs
serve:
    yarn run serve

# Build the container image to run docusaurus
build-container *ARGS='':
    docker build {{ARGS}} -t docusaurus .

# Run docusaurus in a container
#
# Example 1: Start the dev server to host the documentation in a container
# $ just docs-container
#
# Example 2: Start a shell inside the container where you can call the docusaurus commands manually
# $ just docs-container sh
#
# Example 3: Build then serve the production docs (e.g. not the development server)
# $ just docs-container yarn build
# $ just docs-container yarn serve
docs-container *ARGS='yarn start': build-container
    mkdir -p build
    docker run --rm -it \
        --mount "type=bind,src=$PWD/../thin-edge.io/docs/src,target=/docusaurus/docs" \
        --mount "type=bind,src=$PWD/build,target=/docusaurus/build" \
        -p 127.0.0.1:3000:3000/tcp \
        docusaurus {{ARGS}}
