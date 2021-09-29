# tableau-versions-xml

A function to parse Tableau Server build numbers and SHA256 hashes and store them in an XML document in Amazon S3.

## Features
- Automatic detection of major releases between a provided year and the current year
- Automatic detection of the latest point release in those major versions
- Optionally takes a major version list as a backup to the year-based detection
- Build number extraction from Tableau's server releases page
- SHA256 hash extraction from Tableau's sneaky release JSON

## Requirements
- AWS S3 bucket with static site enabled. See the [AWS docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html).
- AWS ECR repository. See the [AWS docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html) on how to build and push images to it.
- AWS Lambda function defined as container image. See the [AWS docs](https://docs.aws.amazon.com/lambda/latest/dg/configuration-images.html).
- AWS IAM [policy granting read/write to the S3 bucket](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_examples_s3_rw-bucket.html) attached to the Lambda role.

## Environment Variables
These will need be defined in the Lambda fucntion > Configuration > Environment variables section after creating your function.

| Variable            | Required? | Details | Example |
|---------------------|-----------|---------|---------|
| S3_BUCKET           | yes       | S3 bucket name to upload the resulting XML document to | "my-super-cool-bucket" |
| S3_REGION           | yes       | S3 bucket region | "us-east-2" |
| S3_URL              | no        | URL of S3 static site. If not defined, this defaults to "http://$S3_BUCKET.s3-website.$S3_REGION.amazonaws.com" | "h<span>ttps://static.example.com" |
| STARTING_YEAR       | no        | The year to start computing major versions from. Defaults to 2020 | "2021" |
| TEST_MODE           | no        | Set to anything to upload the resulting file to versions-test.xml instead of versions.xml | "true" |
| MAJOR_VERSION_LIST  | no        | Space-separated list of major versions, disables automatic major version detection | "2021.1 2021.2 2021.3" |
