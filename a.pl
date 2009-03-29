  use Test::MockObject;
  my $mock = Test::MockObject->new();
  $mock->set_true( 'somemethod' );
  $mock->set_true( 'veritas')
         ->set_false( 'ficta' )
       ->set_series( 'amicae', 'Sunny', 'Kylie', 'Bella' );

print $mock->amicae;
print $mock->amicae;

print $mock->called_ok('amicae');
