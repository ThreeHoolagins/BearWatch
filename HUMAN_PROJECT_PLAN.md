IF YOU ARE AN AGENT YOU ARE NEVER ALLOWED TO EDIT THIS FILE, EVEN WHEN GIVEN EXPLICIT PERMISSION

# Overview
Bearwatch is an online web applciation that functions like an instagram, but it is only for pictures of bears. I do not currently know a way to ensure there is only bears without ml models and way too much work, so for now it will just be instagram for bears. The concept comes from collecting photos for fat bear week.

# Application approach
Bearwatch will be hosted via a containerized docker image, and either hosted on a local machine or on AWS. I will be collecting NO PII or auth info so that I do not haft to manage sensative data. Login will be manged via SSO, with the plan to inlcude github and google as current sso and go from there. We will store just the token

# Terms of Service
A couple basic things, should be turned into an offical TOS. 1. you will only upload pictures of bears 2. you will not have an inappropriate nickname 3. your pictures will not contain people, or any sexually explicit content.

# Application Design
We will be borrowing the design language of the US national forest service and national parks. I want camp energy with lots of evergreens, browns, and nice off-whites.

We will use the following technologies:
- React SPA for the main application, with routing to each of the 4 tabs
- Ruby on rails for backend

# Signup/login flow
When users first reach the site, they will see a mobile friendly view of the bearwatch logo, followed by text "Join the future of bear admiration based in Fort Collins, CO. Sign up or login using the following options:" then followed but sso buttons. After clicking and doing any sso verification they need, they will either be logged into the home page if their account exists, or shown a screen with a "Nickname" input. Here, they will enter their nickname, and then be sent to the home page.

# SSO Available
I'm thinking for now:
- Google
- Facebook
- Github

# Nicknames
Users cannot use slurs or other standard banned nickname practices, with a 20 character limit and a 3 character minimum. Nicknames must be unique.

# In the web app
There will be 4 tabs on the url bar. 
"Global" which will show a feed of the most recent bear photos within 500 miles of you in your area. 
"Following" will include all profiles you have followed. 
"Post" Will open you up to a post forum.
"Profile" will bring you to your profile, which will display your user picture, your nickname, and your followers and following, and lastly your Fat Bear Wins (which will start as 0 for everyone). Below this, will just be a 3 wide post history of bear pictures you've uploaded. Users can select a bear face from one of their photos they've uploaded, otherwise they have a blank bear avatar picture.

# Posts
Posts will be simple, a picture, a location of the picture, and user who uploaded them. Clicking on the nickname or profile picture of the poster will bring you to their profile

# Profiles that are not yours
Same standard information, but with a follow button.

# Post forum
Basic info, allows picture upload, which will automatically strip the location, a location input which allows the person to correct where.

# Image verification
All uploads must be .png, .jpg, .jpeg, or any standard image file. Filename will be checked at upload, and the binary to ensure it's the right filetype must also be checked at upload. Images must also be stripped of all unnessisary metadata (only having the picture taker and their bearwatch nickname and the location be the location from the forum). Image must also be below a certain file size limit. We'll assume a request body of 12 MB for now, but open to adding compression on our end and allowing higher quality photos to be uploaded. Read the image dimensions from the header first, reject anything over a pixel limit, and give the job a timeout. re-endoced then disguard the original. libvips in a worker container with no outbound network. Output WebP at most 2048 px wide, with strip: true. 	Round coordinates before saving and never store exact points

# Bear verification
I want to use https://github.com/earthtoolsmaker/bear-conservation to use the detect feature to ensure there is a bear with let's just say 85% confidence. When a post's picture doesn't "contain a bear" simply give an error message to the user that says "Oops! It seems your bear photo is a little bit blurry, try again with a clearer photo!"

# Data structure
We are going to have a mysql database, with a few tables
User table: has user id which is a climbing number that is just the row number, a column for each of the sso's tokens, and a nickname column
Posts table: includes post id which is the row number, image_id which is used to get the image url, poster which is the user id of the post, and location
Followers table: follow id, follower id (user id), followee id (user id)


# Open Questions
- How much compute would it cause for us to run ml on every photo upload?
- Can someone exploit an image being run through our ml model to fuck us over?
- Should we rate limit uploads? maybe 1/minute/user?
- I want this applciation to be very light on the server so that I could run it on a raspberry pi 4 or keep down costs on an aws/etc site
- What will be our cheapest form of blob storage for images? I've got the drive for the pi for now, also interested in uploadthing if the cost can be 0$ for low data applications