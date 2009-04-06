package Test::Mock::Class::ReturnTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use Test::Mock::Class;

has meta => ( is => 'rw' );

sub set_up {
    my ($self) = @_;
    $self->meta(
        Test::Mock::Class->create_mock_anon_class(
            class => 'Test::Mock::Class::Test::Dummy',
        )
    );
    assert_true($self->meta->isa('Moose::Meta::Class'));
};

sub test_default_return {
    my ($self) = @_;
    $self->meta->add_mock_return_value('a_method' => ( value => 'aaa' ) );
    my $mock = $self->meta->new_object;
    assert_equals('aaa', $mock->a_method);
    assert_equals('aaa', $mock->a_method);
};

sub test_parametered_return {
    my ($self) = @_;
    $self->meta->add_mock_return_value('a_method' => (
        value => 'aaa',
        args  => [1, 2, 3],
    ) );
    my $mock = $self->meta->new_object;
    assert_null($mock->a_method);
    assert_equals('aaa', $mock->a_method(1, 2, 3));
};

1; __END__

function testSetReturnGivesObjectReference() {
    $mock = new MockDummy();
    $object = new Dummy();
    $mock->returns('aMethod', $object, array(1, 2, 3));
    $this->assertSame($mock->aMethod(1, 2, 3), $object);
}

function testSetReturnReferenceGivesOriginalReference() {
    $mock = new MockDummy();
    $object = 1;
    $mock->returnsByReference('aReferenceMethod', $object, array(1, 2, 3));
    $this->assertReference($mock->aReferenceMethod(1, 2, 3), $object);
}

function testReturnValueCanBeChosenJustByPatternMatchingArguments() {
    $mock = new MockDummy();
    $mock->returnsByValue(
            "aMethod",
            "aaa",
            array(new PatternExpectation('/hello/i')));
    $this->assertIdentical($mock->aMethod('Hello'), 'aaa');
    $this->assertNull($mock->aMethod('Goodbye'));
}

function testMultipleMethods() {
    $mock = new MockDummy();
    $mock->returnsByValue("aMethod", 100, array(1));
    $mock->returnsByValue("aMethod", 200, array(2));
    $mock->returnsByValue("anotherMethod", 10, array(1));
    $mock->returnsByValue("anotherMethod", 20, array(2));
    $this->assertIdentical($mock->aMethod(1), 100);
    $this->assertIdentical($mock->anotherMethod(1), 10);
    $this->assertIdentical($mock->aMethod(2), 200);
    $this->assertIdentical($mock->anotherMethod(2), 20);
}

function testReturnSequence() {
    $mock = new MockDummy();
    $mock->returnsByValueAt(0, "aMethod", "aaa");
    $mock->returnsByValueAt(1, "aMethod", "bbb");
    $mock->returnsByValueAt(3, "aMethod", "ddd");
    $this->assertIdentical($mock->aMethod(), "aaa");
    $this->assertIdentical($mock->aMethod(), "bbb");
    $this->assertNull($mock->aMethod());
    $this->assertIdentical($mock->aMethod(), "ddd");
}

function testSetReturnReferenceAtGivesOriginal() {
    $mock = new MockDummy();
    $object = 100;
    $mock->returnsByReferenceAt(1, "aReferenceMethod", $object);
    $this->assertNull($mock->aReferenceMethod());
    $this->assertReference($mock->aReferenceMethod(), $object);
    $this->assertNull($mock->aReferenceMethod());
}

function testReturnsAtGivesOriginalObjectHandle() {
    $mock = new MockDummy();
    $object = new Dummy();
    $mock->returnsAt(1, "aMethod", $object);
    $this->assertNull($mock->aMethod());
    $this->assertSame($mock->aMethod(), $object);
    $this->assertNull($mock->aMethod());
}

function testComplicatedReturnSequence() {
    $mock = new MockDummy();
    $object = new Dummy();
    $mock->returnsAt(1, "aMethod", "aaa", array("a"));
    $mock->returnsAt(1, "aMethod", "bbb");
    $mock->returnsAt(2, "aMethod", $object, array('*', 2));
    $mock->returnsAt(2, "aMethod", "value", array('*', 3));
    $mock->returns("aMethod", 3, array(3));
    $this->assertNull($mock->aMethod());
    $this->assertEqual($mock->aMethod("a"), "aaa");
    $this->assertSame($mock->aMethod(1, 2), $object);
    $this->assertEqual($mock->aMethod(3), 3);
    $this->assertNull($mock->aMethod());
}

function testMultipleMethodSequences() {
    $mock = new MockDummy();
    $mock->returnsByValueAt(0, "aMethod", "aaa");
    $mock->returnsByValueAt(1, "aMethod", "bbb");
    $mock->returnsByValueAt(0, "anotherMethod", "ccc");
    $mock->returnsByValueAt(1, "anotherMethod", "ddd");
    $this->assertIdentical($mock->aMethod(), "aaa");
    $this->assertIdentical($mock->anotherMethod(), "ccc");
    $this->assertIdentical($mock->aMethod(), "bbb");
    $this->assertIdentical($mock->anotherMethod(), "ddd");
}

function testSequenceFallback() {
    $mock = new MockDummy();
    $mock->returnsByValueAt(0, "aMethod", "aaa", array('a'));
    $mock->returnsByValueAt(1, "aMethod", "bbb", array('a'));
    $mock->returnsByValue("aMethod", "AAA");
    $this->assertIdentical($mock->aMethod('a'), "aaa");
    $this->assertIdentical($mock->aMethod('b'), "AAA");
}

function testMethodInterference() {
    $mock = new MockDummy();
    $mock->returnsByValueAt(0, "anotherMethod", "aaa");
    $mock->returnsByValue("aMethod", "AAA");
    $this->assertIdentical($mock->aMethod(), "AAA");
    $this->assertIdentical($mock->anotherMethod(), "aaa");
}

1;
