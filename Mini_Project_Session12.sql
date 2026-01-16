drop database if exists social_network;
create database social_network;
use social_network;

create table USERS (
    user_id int auto_increment primary key,
    username varchar(50) not null unique,
    password varchar(255) not null,
    email varchar(100) not null unique,
    created_at datetime default current_timestamp
);

create table POSTS (
    post_id int auto_increment primary key,
    user_id int,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (user_id) references USERS(user_id)
);
create table COMMENTS (
    comment_id int auto_increment primary key,
    post_id int,
    user_id int,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (post_id) references POSTS(post_id),
    foreign key (user_id) references USERS(user_id)
);
create table FRIENDS (
    user_id int,
    friend_id int,
    status varchar(20),
    check (status in ('pending','accepted')),
    foreign key (user_id) references USERS(user_id),
    foreign key (friend_id) references USERS(user_id)
);

create table LIKES (
    user_id int,
    post_id int,
    foreign key (user_id) references USERS(user_id),
    foreign key (post_id) references POSTS(post_id)
);

-- Bài 1. Thêm & hiển thị user

insert into USERS(username,password,email)
values ('anh','123456','anh@gmail.com');

select * from USERS;
-- Bài 2. View công khai
create view vw_public_users as
select user_id, username, created_at
from USERS;

select * from vw_public_users;
-- Bảo mật: không lộ password, email

-- Bài 3. Index tìm kiếm user
create index idx_users_username on USERS(username);

select * from USERS where username = 'anh';

-- Bài 4. Stored Procedure đăng bài
delimiter $$

create procedure sp_create_post(
    in p_user_id int,
    in p_content text
)
begin
    if exists (select 1 from USERS where user_id = p_user_id) then
        insert into POSTS(user_id, content)
        values (p_user_id, p_content);
    else
        signal sqlstate '45000'
        set message_text = 'user not exists';
    end if;
end$$

delimiter ;
call sp_create_post(1,'hello social network');

-- Bài 5. View news feed

create view vw_recent_posts as
select *
from POSTS
where created_at >= now() - interval 7 day;

select * from vw_recent_posts;
-- Bài 6. Composite index

create index idx_posts_user_time
on POSTS(user_id, created_at);

select *
from POSTS
where user_id = 1
order by created_at desc;
--  Index (user_id, created_at) giúp lọc + sắp xếp

-- Bài 7. Đếm bài viết
delimiter $$

create procedure sp_count_posts(
    in p_user_id int,
    out p_total int
)
begin
    select count(*) into p_total
    from POSTS
    where user_id = p_user_id;
end$$

delimiter ;

call sp_count_posts(1, @total);
select @total;

-- Bài 8. View WITH CHECK OPTION

create view vw_active_users as
select u.user_id, u.username
from USERS u
where exists (
    select 1 from POSTS p where p.user_id = u.user_id
)
with check option;

insert into vw_active_users(user_id, username)
values (100,'test'); --  bị từ chối
-- Bài 9. Kết bạn

delimiter $$

create procedure sp_add_friend(
    in p_user_id int,
    in p_friend_id int
)
begin
    if p_user_id = p_friend_id then
        signal sqlstate '45000'
        set message_text = 'cannot add yourself';
    else
        insert into FRIENDS(user_id, friend_id, status)
        values (p_user_id, p_friend_id, 'pending');
    end if;
end$$

delimiter ;
-- Bài 10. Gợi ý bạn bè
delimiter $$

create procedure sp_suggest_friends(
    in p_user_id int,
    inout p_limit int
)
begin
    select user_id, username
    from USERS
    where user_id != p_user_id
    limit p_limit;
end$$

delimiter ;

set @limit = 5;
call sp_suggest_friends(1, @limit);
-- Bài 11. Top bài viết

create index idx_likes_post on LIKES(post_id);

create view vw_top_posts as
select post_id, count(*) as total_likes
from LIKES
group by post_id
order by total_likes desc
limit 5;

select * from vw_top_posts;

-- Bài 12. Bình luận

delimiter $$

create procedure sp_add_comment(
    in p_user_id int,
    in p_post_id int,
    in p_content text
)
begin
    if not exists (select 1 from USERS where user_id = p_user_id) then
        signal sqlstate '45000'
        set message_text = 'user not exists';
    elseif not exists (select 1 from POSTS where post_id = p_post_id) then
        signal sqlstate '45000'
        set message_text = 'post not exists';
    else
        insert into COMMENTS(user_id, post_id, content)
        values (p_user_id, p_post_id, p_content);
    end if;
end$$

delimiter ;

create view vw_post_comments as
select c.content,
       u.username,
       c.created_at
from COMMENTS c
join USERS u on c.user_id = u.user_id;
-- Bài 13. Lượt thích

delimiter $$

create procedure sp_like_post(
    in p_user_id int,
    in p_post_id int
)
begin
    if exists (
        select 1 from LIKES
        where user_id = p_user_id and post_id = p_post_id
    ) then
        signal sqlstate '45000'
        set message_text = 'already liked';
    else
        insert into LIKES(user_id, post_id)
        values (p_user_id, p_post_id);
    end if;
end$$

delimiter ;

create view vw_post_likes as
select post_id, count(*) as total_likes
from LIKES
group by post_id;
-- Bài 14. Tìm kiếm

delimiter $$

create procedure sp_search_social(
    in p_option int,
    in p_keyword varchar(100)
)
begin
    if p_option = 1 then
        select * from USERS
        where username like concat('%', p_keyword, '%');
    elseif p_option = 2 then
        select * from POSTS
        where content like concat('%', p_keyword, '%');
    else
        signal sqlstate '45000'
        set message_text = 'invalid option';
    end if;
end$$

delimiter ;

call sp_search_social(1,'an');
call sp_search_social(2,'database');