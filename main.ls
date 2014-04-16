require! <[googleapis moment readline fluent-ffmpeg]>

rl = readline.create-interface do
  input: process.stdin
  output: process.stdout

video-id =''
stream-id = ''
stream-url = ''

CLIENT_ID = ''
CLIENT_SECRET = ''
REDIRECT_URI = ''

get-access-token = (auth, next) ->
  url = auth.generate-auth-url do
    access_type: 'offline'
    scope: 'https://www.googleapis.com/auth/youtube'

  console.log 'Vist the url: ' + url
  code <- rl.question 'Enter the Code:'
  err, tokens <- auth.get-token code
  auth.setCredentials tokens
  next!

auth = new googleapis.OAuth2Client CLIENT_ID, CLIENT_SECRET, REDIRECT_URI

transit-it = (auth, client, status,next) ->
  err, it <- client.youtube.live-broadcasts.transition broadcast-status: status, id: video-id, part: 'id,status,contentDetails'
    .with-auth-client auth
    .execute
  next err, it

(err, client) <- googleapis.discover 'youtube', 'v3'
  .execute

<- get-access-token auth
req-broadcast =
  snippet:
    title: 'g0v ly'
    scheduledStartTime: moment(new Date('2014', '3', '18', '5')).format 'YYYY-MM-DDThh:mm:ss.sZ'
    scheduledEndTime: moment(new Date('2014', '3', '18', '20')).format 'YYYY-MM-DDThh:mm:ss.sZ'
  status:
    privacyStatus: 'private'

req-stream =
  snippet:
    title: 'ly 240p'
  cdn:
    format: '240p'
    ingestion-type: 'rtmp'

# create broadcast
err, broadcast <- client.youtube.live-broadcasts.insert part: 'snippet,status', req-broadcast
  .with-auth-client auth
  .execute
return console.log err if err
video-id := broadcast.id
console.log 'Video ID: ' + video-id
# create stream
err, stream <- client.youtube.live-streams.insert part: 'snippet,cdn', req-stream
  .with-auth-client auth
  .execute
return console.log err if err
stream-id:= stream.id
stream-name = stream.cdn.ingestion-info.stream-name
stream-address = stream.cdn.ingestion-info.ingestion-address
stream-url := stream-address + '/' + stream-name
console.log 'Stream ID: ' + stream-id

# bind broadcast and stream
err, bind <- client.youtube.live-broadcasts.bind part: 'id,contentDetails', id: video-id, stream-id: stream-id
  .with-auth-client auth
  .execute
return console.log err if err
new fluent-ffmpeg source: 'rtmp://cp49989.live.edgefcs.net:1935/live/streamRM1@2564'
  .with-video-codec 'libx264'
  .with-audio-codec 'libfaac'
  .with-audio-bitrate '128k'
  .with-audio-channels 1
  .with-audio-frequency 44100
  .with-size '426x240'
  .with-fps 30
  .to-format 'flv'
  .add-options ['-g 1', '-force_key_frames 2']
  .on 'start' -> console.log 'FFmpeg start with ' + it
  .on 'progress' ->
    err, streams <- client.youtube.live-streams.list part: 'id,status', id: stream-id
      .with-auth-client auth
      .execute
    err, test <- transit-it auth, client, 'testing'
    err, live <- transit-it auth, client, 'live'
    console.log live.status.lifeCycleStatus if live
    console.log 'http://www.youtube.com/watch?v=' + video-id if live
  .on 'end' -> console.log 'FFmpeg end.'
  .write-to-stream stream-url
