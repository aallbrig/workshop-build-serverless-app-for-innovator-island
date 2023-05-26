# Realtime Ride Times App
This is a new sam app to capture the real time ride times for innovator island.

###  Hey! I didn't see this SAM app in the innovator island workshop instructions or video!
Yea! So while I'm working through the workshop I'm trying to encode all _manual_ steps into code. _I like making things harder for myself_ but also I like testing my learning.

I turned this [section of the workshop instructions](https://www.eventbox.dev/published/lesson/innovator-island/2-realtime/2-backend.html) into this SAM app.

I would have just added this lambda function to another app but there would have been a circular dependency added since it depends on the Lambda function role from `theme-park-backend` (`<repo root>/apps/samp-app`) and the SNS topic from `theme-park-ride-times` (`<repo root>/apps/ride-controller`).

### Why can't you just follow the instructions 😅
I'm pretty stubborn and I have this "I don't want to do manual steps" instinct I can't shake.

Lol this is probably a contributing factor why I get burned out.

_But still_ learning how to manually click around the web interface to make lambda applications is a skill set I mean to replace by learning more about SAM. _And I'm trying to balance it with a "just get it done" attitude_.

_Am I blessed or cursed with this stubbornness?_
