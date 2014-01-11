Fitbit Auto Sleep
=================

This script will try to best guess your last nights sleep (also works with command line args for arbitrary dates). This means you won't have to remember to put your Fitbit into sleep mode, but you'll still get sleep data.

This script is meant to be run as a cron job, but can be run from the command line as well. 

You must set the following environment variables (gmail variables used to send email):

export FITBIT_TOKEN=your fitbit app token  
export FITBIT_SECRET=your fitbit app secret  
export FITBIT_EMAIL=the email you use to log into the fitbit.com website  
export FITBIT_PASSWORD=the password you use to log into the fitbit.com website  
export FITBIT_BEGIN_SLEEP_THRESHOLD=the number of 0.0 step 5 minutes blocks to use as the threshold for starting sleep  
export FITBIT_END_SLEEP_THRESHOLD=the number of 0.0 step 5 minutes blocks to use as the threshold for ending sleep  
export GMAIL_DOMAIN=your gmail domain (usually gmail.com)  
export GMAIL_USERNAME=your gmail username  
export GMAIL_PASSWORD=your gmail password  
