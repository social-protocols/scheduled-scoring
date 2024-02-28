create table if not exists VoteEvent(
    voteEventId integer not null, 
    userId text not null,
    tagId integer not null,
    parentId integer,
    postId integer not null,
    noteId integer,
    vote int not null,
    createdAt int not null,
    primary key(voteEventId)
) strict;

create table if not exists Vote (
    userId text,
    tagId integer not null,
    parentId integer,
    postId integer not null,
    vote integer not null,
    latestVoteEventId integer not null,
    createdAt integer not null,
    updatedAt integer not null,
    primary key(userId, tagId, postId)
) strict;

create table if not exists Tally (
    tagId integer not null,
    parentId integer,
    postId integer not null,
    latestVoteEventId integer not null,
    count integer not null,
    total integer not null,
    primary key(tagId, postId)
 ) strict;

create table if not exists ConditionalVote (
    userId text,
    tagId integer not null,
    postId integer not null,
    noteId integer not null,
    eventType integer not null,
    informedVote integer not null,
    uninformedVote integer not null,
    primary key(userId, tagId, postId, noteId, eventType)
) strict;

create table if not exists ConditionalTally (
    tagId integer not null,
    postId integer not null,
    noteId integer not null,
    eventType integer not null,
    informedCount integer not null,
    informedTotal integer not null,
    uninformedCount integer not null,
    uninformedTotal integer not null,
    primary key(tagId, postId, noteId, eventType)
) strict;

create table if not exists Post (
    parentId integer,
    id integer not null,
    primary key(id)
) strict;

create table if not exists ScoreEvent(
    scoreEventId        integer not null primary key
    , voteEventId       integer not null
    , voteEventTime     integer not null
    , tagId             integer
    , parentId          integer
    , postId            integer not null
    , topNoteId         integer
    , parentQ           real
    , parentP           real
    , q                 real
    , p                 real
    , count             integer
    , sampleSize        integer
    , overallP          real
    , score             real
) strict;


create table if not exists Score(
    tagId             integer
    , voteEventId       integer not null
    , voteEventTime     integer not null
    , parentId          integer
    , postId            integer not null
    , topNoteId         integer
    , parentQ           real
    , parentP           real
    , q                 real
    , p                 real
    , count             integer
    , sampleSize        integer
    , overallP          real
    , score             real
    , primary key(tagId, postId)
) strict;

create trigger after insert on ScoreEvent begin
    insert or replace into Score(voteEventId, voteEventTime, tagId, parentId, postId, topNoteId, parentQ, parentP, q, p, count, sampleSize, overallP, score) values (
        new.voteEventId,
        new.voteEventTime,
        new.tagId,
        new.parentId,
        new.postId,
        new.topNoteId,
        new.parentQ,
        new.parentP,
        new.q,
        new.p,
        new.count,
        new.sampleSize,
        new.overallP,
        new.score
    ) on conflict(tagId, postId) do update set
        voteEventId = new.voteEventId,
        voteEventTime = new.voteEventTime,
        topNoteId = new.topNoteId,
        parentQ = new.parentQ,
        parentP = new.parentP,
        q = new.q,
        p = new.p,
        count = new.count,
        sampleSize = new.sampleSize,
        overallP = new.overallP,
        score = new.score
    ;
end;


create table if not exists LastVoteEvent (
    type integer,
    importedVoteEventId integer not null default 0,
    processedVoteEventId integer not null default 0,
    primary key(type)
) strict;

create table if not exists LastScoreEvent (
    scoreEventId integer not null default 0
) strict;


insert into LastVoteEvent values(1,0,0);
insert into LastScoreEvent values(0);

create index if not exists post_parent on Post(parentId);
create index if not exists Vote_tag_user_post on Vote(tagId, userId, postId);
create index if not exists ConditionalVote_tag_user_post on ConditionalVote(tagId, userId, postId);
create index if not exists ConditionalVote_tag_user_post_note on ConditionalVote(tagId, userId, postId, noteId);



