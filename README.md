# Workshop: build serverless app for innovator island
This project is based on the instructions for [a workshop by AWS here](https://s12d.com/islandworkshop). Additional links can be found in the resources section.

This is a learning project for me so that I can solidify my serverless application knowledge set.

I enjoy making things more difficult for myself so any manual steps described in the workshop series will be automated. Check out `./scripts/up.sh` and `./scripts/down.sh` to see this effort.

~~[Current Progress Video Bookmark](https://youtu.be/aNgmgZjzNr4?t=1026)~~ Complete!

## Workshop Complete
As of today, I'm declaring that I've finished this workshop.
One goal I had going into this project was to automate as much as I could and I feel I've accomplished that goal.
I did not automate all modules because I manually created AWS QuickSight analysis and dashboards, which was in module 5.
I still feel great about the automation I did accomplish and I learned a lot about AWS services and serverless applications.
It was a lot of work, let me tell you!

I hope this helps other people, either from direct browsing of this project's source code or by the cornucopia of LLMs vacuuming up any and all internet bits. 🫡

#### Possible Future Work
- I have `./scripts/up.sh` and `./scripts/down.sh` which are bash scripts that automate the creation and deletion of the AWS resources. I could refactor this bash script into terraform to allow terraform to be the orchestrator of the sam/cloudformation templates.
- I can automate the manual parts -- largely module 5. I skipped over my self-imposed exercise and instead just created AWS quicksight dashboards.
- Something I did was to create a new "app" in the "apps" directory for each new lambda function. I could consider all resources in this workshop and try to consolidate the cloudformation/sam stacks differently.
- Have a better local testing story. While I did learn more about tools like `sam local invoke` to test lambda functions locally I feel like I could explore this more. See `./scripts/test.sh` for more.
- Try to get the adjustments I made for my issue (see #Issues below) into the upstream repo.

## Issues
- `[ERROR] Runtime.ImportModuleError: Unable to import module 'app': urllib3 v2.0 only supports OpenSSL 1.1.1+, currently the 'ssl' module is compiled with OpenSSL 1.0.2k-fips  26 Jan 2017. See: https://github.com/urllib3/urllib3/issues/2168
  Traceback (most recent call last):`

    ~~If I want to compile a new version of the opencv library, this might be helpful: [https://github.com/awslabs/lambda-opencv](https://github.com/awslabs/lambda-opencv)~~
    Fixed in [aallbrig/lambda-opencv python39-only tag](https://github.com/aallbrig/lambda-opencv/tree/python39-only) ^_^


## Resources
1. [Youtube Playlist of the series](https://www.youtube.com/watch?v=GhZpSYQ6F9M&list=PL5bUlblGfe0LpQv23EVaUmeWkD7ZddnAw)
1. [Build a Serverless Web App for a Theme Park: Episode 1 - AWS Virtual Workshop](https://youtu.be/GhZpSYQ6F9M)
1. [Build a Serverless Web App for a Theme Park: Episode 2 - AWS Virtual Workshop](https://youtu.be/EhgOoFbCID0)
1. [Build a Serverless Web App for a Theme Park: Episode 3 - AWS Virtual Workshop](https://youtu.be/aNgmgZjzNr4)
1. [Build a Serverless Web App for a Theme Park: Episode 4 - AWS Virtual Workshop](https://youtu.be/G1Hukehp52Q)
1. [Build a Serverless Web App for a Theme Park: Episode 5 - AWS Virtual Workshop](https://youtu.be/FOwoq6uEcJw)
1. [aws-samples/aws-serverless-workshop-innovator-island](https://github.com/aws-samples/aws-serverless-workshop-innovator-island)
