use strict;
use warnings;
package App::Inactio::Request;

sub is_error { die "override this" }

sub is_recovery { die "override this" }

sub project_name { die "override this" }

sub name { die "override this" }

sub expand_param { die "override this" }

1;
