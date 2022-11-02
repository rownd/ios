# Releasing new versions of the Rownd iOS SDK

## Setup

It'll make things easier if you set a `GITHUB_TOKEN` environment variable with a GitHub Personal Access Token that has all `repo` permissions.

<img width="481" alt="image" src="https://user-images.githubusercontent.com/130131/199608211-9471d610-5be5-4251-8699-17c7f49fd147.png">


## 1. Tag to release Swift Package Manager (SPM) package

From your local machine do the following:

1. Pull latest main branch and ensure there are no uncommitted or untested changes present.
   Run `git reset --hard origin/master` if you need to make sure.
2. Run `npm install` if needed
3. Run `npm run release` and answer `y` for all questions

SPM should now be able to pull the latest package version.

## 2. Release to CocoaPods

After releasing to SPM, push to CocoaPods.

1. Update the version number in the `Rownd.podspec` file to match the version just released to SPM.
2. Run `pod trunk push . --allow-warnings` to push the podspec to the CocoaPods main repo.
3. Commit the change to the podspec with the message `chore: release vX.Y.Z to cocoapods` (replacing `X.Y.Z` with the actual released version number).
4. Push to GitHub

That's it!
