package WebObvius::Cache::Cache;

use strict;
use warnings;

use WebObvius::Cache::ExternalUserCache;
use WebObvius::Cache::ExternalApacheCache;
use WebObvius::Cache::MysqlApacheCache;
use WebObvius::Cache::Collection;
use WebObvius::Cache::AdminLeftmenuCache;
use WebObvius::Cache::MysqlAdminLeftmenuCache;
use WebObvius::Cache::InternalProxyCache;
use WebObvius::Cache::ExternalMedarbejderoversigtCache;

our @ISA = qw( WebObvius::Cache::Collection );

sub new {
    my ($class, $obvius) = @_;
    
    my $user_cache     = WebObvius::Cache::ExternalUserCache->new($obvius);
    my $leftmenu_cache;
    if($obvius->config->param('use_old_admin_leftmenu_cache')) {
        $leftmenu_cache = WebObvius::Cache::AdminLeftmenuCache->new($obvius);
    } else {
        $leftmenu_cache = WebObvius::Cache::MysqlAdminLeftmenuCache->new($obvius);
    }

    my $apache_cache;
    if($obvius->config->param('mysql_apachecache_table')) {
        $apache_cache = WebObvius::Cache::MysqlApacheCache->new($obvius);
    } else {
        $apache_cache = WebObvius::Cache::ExternalApacheCache->new($obvius);
    }

    my $internal_proxy_cache = WebObvius::Cache::InternalProxyCache->new($obvius);
    
    my $medarbejderoversigt_cache = WebObvius::Cache::ExternalMedarbejderoversigtCache->new($obvius);

    my @extras;
    if(my $extra_modules = $obvius->config->param('extra_cache_modules')) {
        for my $modulename (split(/\s*,\s*/, $extra_modules)) {
            eval {
                my $filename = "$modulename.pm";
                $filename =~ s!::!/!g;
                require $filename;
                my $module = $modulename->new($obvius);
                push(@extras, $module);
            };
            warn $@ if($@);
        }
    }
   
    return $class->SUPER::new($user_cache, 
                              $leftmenu_cache, 
                              $apache_cache, 
                              $internal_proxy_cache,
                              $medarbejderoversigt_cache,
                              @extras);
}

1;
