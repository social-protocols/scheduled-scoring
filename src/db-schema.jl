function create_tables(db::SQLite.DB)
    stmts = [
        """
        create table VoteEvent(
              vote_event_id   integer not null
            , vote_event_time integer not null
            , user_id         text    not null
            , parent_id       integer
            , post_id         integer not null
            , vote            integer not null
            , primary key(vote_event_id)
        ) strict;
        """,
        """
        create table PostCreationEvent(
              post_id   integer not null
            , parent_id integer
            , primary key(post_id)
        ) strict;
        """,
        """
        create table Vote(
              vote_event_id   integer not null
            , vote_event_time integer not null
            , user_id         text not null
            , parent_id       integer
            , post_id         integer not null
            , vote            integer not null
            , primary key(user_id, post_id)
        ) strict;
        """,
        """
        create table Tally(
              parent_id            integer
            , post_id              integer not null
            , latest_vote_event_id integer not null
            , count                integer not null
            , total                integer not null
            , primary key(post_id)
        ) strict;
        """,
        """
        create table InformedVote(
          user_id text not null,
          post_id integer not null,
          comment_id integer not null,
          vote integer not null,
          informed integer not null,
          primary key(user_id, post_id, comment_id)
        ) strict;
        """,
        """
        create table InformedTally(
              post_id          integer not null
            , comment_id          integer not null
            , count   integer not null
            , total   integer not null
            , primary key(post_id, comment_id)
         ) strict;
        """,
        """
        create table PreinformedVote(
          user_id text not null,
          post_id integer not null,
          comment_id integer not null,
          vote integer not null,
          last_vote_event_id integer not null,
          primary key(user_id, post_id, comment_id)
        ) strict;
        """,
        """
        create table PreinformedTally(
              post_id          integer not null
            , comment_id          integer not null
            , count   integer not null
            , total   integer not null
            , primary key(post_id, comment_id)
         ) strict;
        """,
        """
        create table Post(
              parent_id  integer
            , id         integer not null
            , first_vote_event_id integer not null
            , content    text default ''
            , primary key(id)
        ) strict;
        """,
        """
        create index post_parent on Post(parent_id);
        """,
        """
        create table Lineage(
              ancestor_id   integer
            , descendant_id integer not null
            , separation    integer not null
            , primary key(ancestor_id, descendant_id)
        ) strict;
        """,
        """
        create index Lineage_ancestor_id
        on Lineage(ancestor_id);
        """,
        """
        create index Lineage_descendant_id
        on Lineage(descendant_id);
        """,
        """
        create table EffectEvent(
              vote_event_id   integer not null
            , vote_event_time integer not null
            , post_id         integer not null 
            , comment_id         integer not null
            , top_subthread_id         integer
            , p               real    not null
            , p_count         integer not null
            , p_size          integer not null
            , q               real    not null
            , q_count         integer not null
            , q_size          integer not null
            , r               real    not null
            , primary key(vote_event_id, post_id, comment_id)
        ) strict;
        """,
        """
        create table Effect(
              vote_event_id   integer not null
            , vote_event_time integer not null
            , post_id         integer not null 
            , comment_id         integer not null
            , top_subthread_id         integer
            , p               real    not null
            , p_count         integer not null
            , p_size          integer not null
            , q               real    not null
            , q_count         integer not null
            , q_size          integer not null
            , r               real    not null
            , primary key(post_id, comment_id)
        ) strict;
        """,
        """
        create index Effect_post
        on Effect(post_id);
        """,
        """
        create table ScoreEvent(
              vote_event_id     integer not null
            , vote_event_time   integer not null
            , post_id           integer not null
            , top_comment_id       integer
            , critical_thread_id       integer
            , o                 real    not null
            , o_count           integer not null
            , o_size            integer not null
            , p                 real    not null
            , score             real    not null
            , primary key(vote_event_id, post_id)
        ) strict;
        """,
        """
        create table Score(
              vote_event_id     integer not null
            , vote_event_time   integer not null
            , post_id           integer not null
            , top_comment_id       integer
            , critical_thread_id       integer
            , o                 real    not null
            , o_count           integer not null
            , o_size            integer not null
            , p                 real    not null
            , score             real    not null
            , primary key(post_id)
        ) strict;
        """,
        """
        create table LastVoteEvent(
              type                    integer
            , vote_event_id  integer not null default 0
            , voted_on_post_id integer
            , primary key(type)
        ) strict;
        """,
        """
        insert into LastVoteEvent values(1, 0, null);
        """,
    ]

    map((stmt) -> DBInterface.execute(db, stmt), stmts)
end

function create_views(db::SQLite.DB)
    stmts = [
        """
        create view VoteEventImport as
        select
            0  as vote_event_id,
            '' as user_id,
            '' as parent_id,
            0  as post_id,
            0  as vote,
            0  as vote_event_time;
        """,
        """
        create view DirectlyInformedVote as
          select
            Vote.user_id
            , targetVote.post_id as post_id
            , Vote.post_id as comment_id
            , targetVote.vote as vote
            , Vote.vote != 0 as informed
            , Vote.post_id as informed_by_comment_id
          from
            Vote join Lineage on
              Lineage.descendant_id = Vote.post_id
            join Vote targetVote on
              targetVote.user_id = Vote.user_id
              and targetVote.post_id = Lineage.ancestor_id
        ;
        """,
        """
        create view IndirectlyInformedVote as
          select
            iv.user_id
            , iv.post_id
            , Lineage.ancestor_id as comment_id
            , iv.vote as vote
            , (iv.informed or ifnull(vote.vote,0) != 0) as informed
            , iv.comment_id as informed_by_comment_id
          from 
          DirectlyInformedVote iv
          join Lineage
            on Lineage.descendant_id = iv.comment_id
            and Lineage.ancestor_id > iv.post_id
          left join vote 
            on vote.post_id = Lineage.ancestor_id
            and vote.user_id = iv.user_id
          where
            iv.informed = 1
        ;
        """,
        """

        create view InformedVoteView as

          select
            user_id
            , post_id
            , comment_id
            , vote

            -- this windowing function is a performance bottleneck. It is necessary because there can be both
            -- an indirectly and directly informed vote record, each of which could have a value of 0 in the informed field
            -- we need both records in the output, because the trigger that inserts into InformedVote
            -- needs to find the correct row based on informed_by_comment_id, but the value of the informed
            -- field should be the same for both rows.

            , max(informed) over (partition by user_id, post_id, comment_id) as informed
            , informed_by_comment_id
          from (
            select
              *
            from DirectlyInformedVote

            UNION ALL

            select
              *
            from IndirectlyInformedVote
          )
        ;     
        """,
        """
        create view PreinformedVoteView as 
            select
                  informed.user_id
                , informed.post_id
                , informed.comment_id
                , case when informed.vote != 0 and informed.informed and preinformed.vote != 0 then preinformed.vote else 0 end as vote
                , max(vote_event_id) as last_vote_event_id
            from
            informedVote informed
            join post comment on comment.id = informed.comment_id
            join voteEvent preinformed using (post_id, user_id)
            where vote_event_id <= comment.first_vote_event_id
            group by informed.post_id, informed.comment_id, informed.user_id;
        """,
        """
        create view ConditionalTally as 

        -- this query is somewhat counter-intuitive. The strangeness arises from this rule:
        -- Only count user as uninformed of a post when the user is informed of the parent of the post.
        -- This rule is described here: https://github.com/social-protocols/internal-wiki/blob/main/pages/research-notes/2024-05-24-calculating-tallies.md
        --
        -- The the uninformed tally is just the partially-informed tally minus
        -- the informed tally. The partially-informed tally is the tally of users who are informed
        -- of the parent of the comment but not the comment itself.

        -- So our first step is to select all partially-informed tallies.
        with PartiallyInformed as (
          -- The partially-informed tally for comment C and target A is the
          -- informed tally of the parent of C and target A.
          select * from InformedTally
          UNION ALL
          -- If the comment is a direct child of the target then the
          -- partially-informed tally is the overall tally for the target.
          select post_id, post_id as comment_id, count, total
          from tally
        )
        select
            Informed.post_id
          , Informed.comment_id
          , Informed.count as informed_count
          , Informed.total as informed_total
          , PartiallyInformed.count - Informed.count + ifnull(Preinformed.count,0) as uninformed_count
          , PartiallyInformed.total - Informed.total + ifnull(Preinformed.total,0) as uninformed_total
        from
          InformedTally Informed 
          join Post on (post.id = Informed.comment_id)
          join PartiallyInformed on
            PartiallyInformed.comment_id = post.parent_id
            and PartiallyInformed.post_id = informed.post_id
          left join PreinformedTally Preinformed using(post_id, comment_id)
        ;

        ;
        """,
    ]

    map((stmt) -> DBInterface.execute(db, stmt), stmts)
end

function create_triggers(db::SQLite.DB)

    stmts = [
        """
        create trigger afterInsertEffectEvent after insert on EffectEvent begin
            insert or replace into Effect
            values (
                  new.vote_event_id
                , new.vote_event_time
                , new.post_id
                , new.comment_id
                , new.top_subthread_id
                , new.p
                , new.p_count
                , new.p_size
                , new.q
                , new.q_count
                , new.q_size
                , new.r
            );
        end;
        """,
        """
        create trigger afterInsertScoreEvent after insert on ScoreEvent begin
            insert or replace into Score
            values (
                new.vote_event_id
                , new.vote_event_time
                , new.post_id
                , new.top_comment_id
                , new.critical_thread_id
                , new.o
                , new.o_count
                , new.o_size
                , new.p
                , new.score
            );
        end;
        """,
        """
        -- Inserting into ProcessVoteEvent will "process" the event and update the tallies, but only if the event hasn't been processed
        -- that is, if the vote_event_id is greater than lastVoteEvent.vote_event_id
        create trigger afterInsertOnInsertVoteEventImport instead of insert on VoteEventImport
        begin

            insert into VoteEvent(
                  vote_event_id
                , vote_event_time
                , user_id
                , parent_id
                , post_id
                , vote
            ) 
            select
                  new.vote_event_id
                , new.vote_event_time
                , new.user_id
                , case when new.parent_id = '' then null else new.parent_id end as parent_id
                , new.post_id
                , new.vote
            ;

            update LastVoteEvent set vote_event_id = new.vote_event_id, voted_on_post_id = new.post_id where vote_event_id < new.vote_event_id;

        end;
        """,
        """
        create trigger afterInsertPost after insert on Post
        when new.parent_id is not null
        begin

            -- Insert a Lineage record for parent
            insert into Lineage(ancestor_id, descendant_id, separation)
            values(new.parent_id, new.id, 1) on conflict do nothing;

            -- Insert a Lineage record for all ancestors of this parent
            insert into Lineage
            select 
                  ancestor_id
                , new.id as descendant_id
                , 1 + separation as separation
            from Lineage ancestor 
            where ancestor.descendant_id = new.parent_id;
        end;
        """,


        # These SQL statements calculate the conditional tallies. These give us the tallies of votes on a post given users were or were not informed of the comment.
        # The logic and reasoning behind these calculations is discussed here:
        # https://github.com/social-protocols/internal-wiki/blob/main/pages/research-notes/2024-05-24-calculating-tallies.md
        #
        # The informed tally table is an aggregate of the **informed vote**
        # table. The informed vote table tells has an entry for every informed vote
        # e.g. for every target-comment combination a user has voted on. Since a
        # a user can become-uninformed by clearing votes, the "informed" field 
        # in this table can be zero.
        """
        create trigger afterInsertOnVoteEvent after insert on VoteEvent
        begin

            -- Insert/update the vote record
            insert into Vote(
                  vote_event_id
                , vote_event_time
                , user_id
                , parent_id
                , post_id
                , vote
            )
            values(
                  new.vote_event_id
                , new.vote_event_time
                , new.user_id
                , new.parent_id
                , new.post_id
                , new.vote
            ) on conflict(user_id, post_id) do update set
                  vote            = new.vote
                , vote_event_id   = new.vote_event_id
                , vote_event_time = new.vote_event_time
            ;

            -- Insert a record for the post the first time we see this post id.
            insert into Post(parent_id, id, first_vote_event_id)
            values(new.parent_id, new.post_id, new.vote_event_id) on conflict do nothing;


            -- Insert an informed vote record for all ancestors and descendants of this post_id
            insert into InformedVote
            select
              user_id
              , post_id
              , comment_id
              , vote
              , informed
            from InformedVoteView
            where 
              (informed_by_comment_id = new.post_id or post_id = new.post_id)
              and user_id = new.user_id
            group by user_id, post_id, comment_id
            on conflict(user_id, post_id, comment_id) do update set
              informed = excluded.informed
              , vote = excluded.vote
            ;


        end;
        """,
        """
        create trigger afterInsertVote after insert on Vote begin

            insert into Tally(
                  parent_id
                , post_id
                , latest_vote_event_id
                , count
                , total
            )
            values (
                  new.parent_id
                , new.post_id
                , new.vote_event_id
                , (new.vote == 1)
                , (new.vote != 0)
            ) on conflict(post_id) do update 
            set 
                  total                = total + (new.vote != 0)
                , count                = count + (new.vote == 1)
                , latest_vote_event_id = new.vote_event_id
            ;

        end;
        """,
        """
        create trigger afterUpdateVote after update on Vote begin
            update Tally
            set 
                total                  = total + (new.vote != 0) - (old.vote != 0)
                , count                = count + (new.vote == 1) - (old.vote == 1)
                , latest_vote_event_id = new.vote_event_id
            where post_id = new.post_id
            ;

        end;
        """,
        """
        create trigger afterInsertInformedVote after insert on InformedVote 
        when new.informed = 1 
        begin
           insert into InformedTally(
                  post_id
                , comment_id
                , count
                , total
            ) 
            values (
                  new.post_id
                , new.comment_id
                , (new.vote = 1)
                , (new.vote != 0)
            ) 
            on conflict(post_id, comment_id) do update
            set
                  count   = count + (new.vote = 1)
                , total   = total + (new.vote != 0)
            ;

            insert into PreinformedVote
            select * from PreinformedVoteView where
              user_id = new.user_id
              and post_id = new.post_id
              and comment_id = new.comment_id
            on conflict do update set
              vote = excluded.vote
              , last_vote_event_id = excluded.last_vote_event_id
            ;

        end;
        """,
        """
        create trigger afterUpdateInformedVote after update on InformedVote begin
            update InformedTally
            set
                count     = count + ((new.vote = 1 and new.informed) - (old.vote = 1 and old.informed))
                , total   = total + ((new.vote != 0 and new.informed) - (old.vote != 0 and old.informed))
            where
            post_id = new.post_id
            and comment_id = new.comment_id
            ;

            insert into PreinformedVote
            select * from PreinformedVoteView where
              user_id = new.user_id
              and post_id = new.post_id
              and comment_id = new.comment_id
            on conflict do update set
              vote = excluded.vote
              , last_vote_event_id = excluded.last_vote_event_id
            ;
        end;
        """,
        """
        create trigger afterInsertPreinformedVote after insert on PreinformedVote 
        begin
           insert into PreinformedTally(
                  post_id
                , comment_id
                , count
                , total
            )
            values (
                  new.post_id
                , new.comment_id
                , (new.vote = 1)
                , (new.vote != 0)
            )
            on conflict(post_id, comment_id) do update
            set
                  count   = count + (new.vote = 1)
                , total   = total + (new.vote != 0)
            ;
        end;
        """,
        """
        create trigger afterUpdatePreinformedVote after update on PreinformedVote begin
            update PreinformedTally
            set
                count     = count + ((new.vote = 1) - (old.vote = 1))
                , total   = total + ((new.vote != 0) - (old.vote != 0))
            where
            post_id = new.post_id
            and comment_id = new.comment_id
            ;
        end;

        """,
    ]

    map((stmt) -> DBInterface.execute(db, stmt), stmts)
end
