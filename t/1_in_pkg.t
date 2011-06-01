#!/usr/bin/env perl

use Test::More;
BEGIN { use_ok('IO::Socket::Socks::Wrapper') };
require 't/subs.pm';
use strict;

SKIP: {
	eval { require LWP::UserAgent; require LWP::Protocol::http; }
		or skip "No LWP found";
		
	my ($s_pid, $s_host, $s_port) = make_socks_server(4);
	my ($h_pid, $h_host, $h_port) = make_http_server();
	
	IO::Socket::Socks::Wrapper->import(
		LWP::Protocol::http::Socket:: => {
			ProxyAddr => $s_host,
			ProxyPort => $s_port,
			SocksVersion => 4
		}
	);
	
	my $ua = LWP::UserAgent->new();
	my $page = $ua->get("http://$h_host:$h_port/")->content;
	is($page, 'ROOT', 'LWP+Socks4+Server');
	
	kill 15, $s_pid;
	$page = $ua->get("http://$h_host:$h_port/")->content;
	isnt($page, 'ROOT', 'LWP+Socks4-Server');
	
	kill 15, $h_pid;
};

SKIP: {
	eval { require Net::HTTP }
		or skip "No Net::HTTP found";
	
	my ($s_pid, $s_host, $s_port) = make_socks_server(5);
	my ($h_pid, $h_host, $h_port) = make_http_server();
	
	IO::Socket::Socks::Wrapper->import(
		Net::HTTP:: => {
			ProxyAddr => $s_host,
			ProxyPort => $s_port
		}
	);
	
	my $http = Net::HTTP->new(Host => $h_host, PeerPort => $h_port);
	my $page;
	eval {
		$http->write_request(GET => '/index');
		$http->read_response_headers();
		$http->read_entity_body($page, 1024);
	};
	is($page, 'INDEX', 'HTTP+Socks5+Server');
	
	kill 15, $s_pid;
	$http = Net::HTTP->new(Host => $h_host, PeerPort => $h_port);
	$page = '';
	eval {
		$http->write_request(GET => '/index');
		$http->read_response_headers();
		$http->read_entity_body($page, 1024);
	};
	isnt($page, 'INDEX', 'HTTP+Socks5-Server');
	
	kill 15, $h_pid;
};

SKIP: {
	eval { require LWP; require Net::FTP }
		or skip "No LWP or no Net::FTP";
		
	my ($s4_pid, $s4_host, $s4_port) = make_socks_server(4);
	my ($s5_pid, $s5_host, $s5_port) = make_socks_server(5);
	my ($h_pid, $h_host, $h_port) = make_http_server();
	my ($f_pid, $f_host, $f_port) = make_ftp_server();
	
	IO::Socket::Socks::Wrapper->import(
		Net::FTP:: => {
			ProxyAddr => $s4_host,
			ProxyPort => $s4_port,
			SocksVersion => 4
		},
		Net::HTTP:: => {
			ProxyAddr => $s5_host,
			ProxyPort => $s5_port,
			SocksVersion => 5
		}
	);
	
	ok(eval{Net::FTP->new($f_host, Port => $f_port)->login('root', 'toor')}, 'FTP over socks4');
	kill 15, $s4_pid;
	
	is(LWP::UserAgent->new->get("http://$h_host:$h_port/index")->content, 'INDEX', 'LWP over socks5');
	kill 15, $s5_pid;
	
	kill 15, $h_pid;
	kill 15, $f_pid;
}

done_testing();