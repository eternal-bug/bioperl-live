BEGIN {
    use lib '.';
    use Bio::Root::Test;

    test_begin( -tests => 486,
                -requires_modules => [qw(Bio::DB::Fasta Bio::SeqIO)] );
}
use strict;
use warnings;
use Config;
use Bio::Root::Root;
use File::Copy;
use File::Basename;
use File::Spec::Functions qw(catfile);
my $DEBUG = test_debug();


# Test Bio::DB::Fasta, but also the underlying module, Bio::DB::IndexedBase

my $test_dir         = setup_temp_dir('dbfa');
my $test_file_1      = setup_temp_file('dbfa', '1.fa');
my $test_file_2      = setup_temp_file('dbfa', '2.fa');
my $test_file_3      = setup_temp_file('dbfa', '3.fa');
my $test_file_6      = setup_temp_file('dbfa', '6.fa');
my $test_file_bad    = setup_temp_file('badfasta.fa');
my $test_file_mixed  = setup_temp_file('dbfa', 'mixed_alphabet.fasta');
my $test_file_spaced = setup_temp_file('spaced_fasta.fa');


for my $dbi ('SDBM_File', 'DB_File', 'GDBM_File') {
SKIP: {
    test_skip(-tests => 162, -requires_module => $dbi);

    @AnyDBM_File::ISA = ($dbi);
    diag "Testing $dbi interface\n";

    {
        # Test basic functionalities
        ok my $db = Bio::DB::Fasta->new($test_dir, -reindex => 1), 'Index a directory';
        is $db->glob, '*.{fa,FA,fasta,FASTA,fast,FAST,dna,DNA,fna,FNA,faa,FAA,fsa,FSA}';
        isa_ok $db, 'Bio::DB::Fasta';
        is $db->length('CEESC13F'), 389;
        is $db->seq('CEESC13F:1,10'), 'cttgcttgaa';
        is $db->seq('CEESC13F:1-10'), 'cttgcttgaa';
        is $db->seq('CEESC13F:1..10'), 'cttgcttgaa';
        is $db->seq('CEESC13F:1..10/1'), 'cttgcttgaa';
        is $db->seq('CEESC13F:1..10/+1'), 'cttgcttgaa';
        is $db->seq('CEESC13F:1..10/-1'), 'ttcaagcaag';
        is $db->seq('CEESC13F/1'), 'cttgcttgaaaaatttatataaatatttaagagaagaaaaataaataatcgcatctaatgacgtctgtccttgtatccctggtttccattgactggtgcactttcctgtctttgaggacatggacaatattcggcatcagttcctggctctccctcctctcctggtgctccagcagaaccgttctctccattatctcccttgtctccacgtggtccacgctctcctggtgctcctggaataccttgagctccctcgtgccgaattcctgcagcccgggggatccactagttctagagcggccgccaccgcggtgggagctccagcttttgttncctttagtgagggttaatttcgagcttggcgtaatcatggtcatagctgtttcctg';
        is $db->seq('CEESC13F/-1'), 'caggaaacagctatgaccatgattacgccaagctcgaaattaaccctcactaaaggnaacaaaagctggagctcccaccgcggtggcggccgctctagaactagtggatcccccgggctgcaggaattcggcacgagggagctcaaggtattccaggagcaccaggagagcgtggaccacgtggagacaagggagataatggagagaacggttctgctggagcaccaggagaggagggagagccaggaactgatgccgaatattgtccatgtcctcaaagacaggaaagtgcaccagtcaatggaaaccagggatacaaggacagacgtcattagatgcgattatttatttttcttctcttaaatatttatataaatttttcaagcaag';
        is $db->seq('AW057119', 1, 10), 'tcatgttggc';
        is $db->seq('AW057119', 1, 10, 1), 'tcatgttggc';
        is $db->seq('AW057119', 1, 10, -1), 'gccaacatga';
        is $db->seq('AW057119', 10, 1), 'gccaacatga';
        is $db->seq('AW057119', 10, 1, -1), 'tcatgttggc';
        is $db->header('AW057119'), 'AW057119 test description';
        is $db->seq('foobarbaz'), undef;
        is $db->get_Seq_by_id('foobarbaz'), undef;
        is $db->file('AW057119'), '1.fa';
        is $db->file('AW057410'), '3.fa';
        is $db->file('CEESC13F'), '6.fa';
        is $db->filepath('AW057119'), catfile($test_dir, '1.fa');
        is $db->filepath('AW057410'), catfile($test_dir, '3.fa');
        is $db->filepath('CEESC13F'), catfile($test_dir, '6.fa');
        is $db->path(), $test_dir;

        # Bio::DB::RandomAccessI and Bio::DB::SeqI methods
        ok my $primary_seq = $db->get_Seq_by_id('AW057119');
        ok $primary_seq = $db->get_Seq_by_acc('AW057119');
        ok $primary_seq = $db->get_Seq_by_version('AW057119');
        ok $primary_seq = $db->get_Seq_by_primary_id('AW057119');
        isa_ok $primary_seq, 'Bio::PrimarySeq::Fasta';
        isa_ok $primary_seq, 'Bio::PrimarySeqI';

        # Bio::PrimarySeqI methods
        is $primary_seq->id, 'AW057119';
        is $primary_seq->display_id, 'AW057119';
        like $primary_seq->primary_id, qr/^Bio::PrimarySeq::Fasta=HASH/;
        is $primary_seq->alphabet, 'dna';
        is $primary_seq->accession_number, 'unknown';
        is $primary_seq->is_circular, undef;
        is $primary_seq->subseq(11, 20), 'ttctcggggt';
        is $primary_seq->description, 'test description', 'bug 3126';
        is $primary_seq->seq, 'tcatgttggcttctcggggtttttatggattaatacattttccaaacgattctttgcgccttctgtggtgccgccttctccgaaggaactgacgaaaaatgacgtggatttgctgacaaatccaggcgaggaatatttggacggattgatgaaatggcacggcgacgagcgacccgtgttcaaaagagaggacatttatcgttggtcggatagttttccagaatatcggctaagaatgatttgtctgaaagacacgacaagggtcattgcagtcggtcaatattgttactttgatgctctgaaagaaaggagagcagccattgttcttcttaggattgggatggacggatcctgaatatcgtaatcgggcagttatggagcttcaagcttcgatggcgctggaggagagggatcggtatccgactgccaacgcggcatcgcatccaaataagttcatgaaacgattttggcacatattcaacggcctcaaagagcacgaggacaaaggtcacaaggctgccgctgtttcatacaagagcttctacgacctcanagacatgatcattcctgaaaatctggatgtcagtggtattactgtaaatgatgcacgaaaggtgccacaaagagatataatcaactacgatcaaacatttcatccatatcatcgagaaatggttataatttctcacatgtatgacaatgatgggtttggaaaagtgcgtatgatgaggatggaaatgtacttggaattgtctagcgatgtctttanaccaacaagactgcacattagtcaattatgcagatagcc';
        ok my $trunc = $primary_seq->trunc(11,20);
        isa_ok $trunc, 'Bio::PrimarySeq::Fasta';
        isa_ok $trunc, 'Bio::PrimarySeqI';
        is $trunc->length, 10;
        is $trunc->seq, 'ttctcggggt';
        ok my $rev = $trunc->revcom;
        isa_ok $rev, 'Bio::PrimarySeq::Fasta';
        isa_ok $rev, 'Bio::PrimarySeqI';
        is $rev->seq, 'accccgagaa';
        is $rev->length, 10;
    }


    SKIP: {
        test_skip(-tests => 3, -requires_modules => [qw(Class::Unload)]);
        # Re-open an existing index.
        # Doing this test properly involves unloading and reloading Bio::DB::Fasta.
        use_ok('Class::Unload');
        Class::Unload->unload( 'Bio::DB::Fasta' );
        Class::Unload->unload( 'Bio::DB::IndexedBase' );
        require Bio::DB::Fasta;
        ok my $db = Bio::DB::Fasta->new($test_dir), 'Re-open an existing index';
        is $db->seq('AW057119', 1, 10), 'tcatgttggc';
    }


    {
        # Test tied hash access
        my %h;
        ok tie(%h, 'Bio::DB::Fasta', $test_dir), 'Tied hash access';
        ok exists $h{'AW057146'};
        is $h{'AW057146:1,10'} , 'aatgtgtaca'; # in file 1.fa
        is $h{'AW057146:10,1'} , 'tgtacacatt'; # reverse complement
        is $h{'AW057443:11,20'}, 'gaaccgtcag'; # in file 4.fa
    }


    {
        # Test writing the Bio::PrimarySeq::Fasta objects with SeqIO
        ok my $db = Bio::DB::Fasta->new($test_dir, -reindex => 1), 'Writing with SeqIO';
        my $out = Bio::SeqIO->new(
            -format => 'genbank',
            -file   => '>'.test_output_file()
        );
        my $primary_seq = Bio::Seq->new(-primary_seq => $db->get_Seq_by_acc('AW057119'));
        eval {
            $out->write_seq($primary_seq)
        };
        is $@, '';

        $out = Bio::SeqIO->new(-format => 'embl', -file  => '>'.test_output_file());
        eval {
            $out->write_seq($primary_seq)
        };
        is $@, '';
    }


    {
        # Test alphabet and reverse-complement RNA
        ok my $db = Bio::DB::Fasta->new( $test_file_mixed, -reindex => 1), 'Index a single file';
        is $db->alphabet('gi|352962132|ref|NG_030353.1|'), 'dna';
        is $db->alphabet('gi|352962148|ref|NM_001251825.1|'), 'rna';
        is $db->alphabet('gi|194473622|ref|NP_001123975.1|'), 'protein';
        is $db->alphabet('gi|61679760|pdb|1Y4P|B'), 'protein';
        is $db->alphabet('123'), '';
        is $db->seq('gi|352962148|ref|NM_001251825.1|', 20, 29,  1), 'GUCAGCGUCC';
        is $db->seq('gi|352962148|ref|NM_001251825.1|', 20, 29, -1), 'GGACGCUGAC';

        # Test empty sequence
        is $db->seq('123'), '';

        is $db->file('gi|352962132|ref|NG_030353.1|'), 'mixed_alphabet.fasta';
        is $db->filepath('gi|352962132|ref|NG_030353.1|'), $test_file_mixed;
        my $dir  = (fileparse($test_file_mixed, qr/\.[^.]*/))[1];
        my $dir2 = $db->path();
        like $dir, qr/^$dir2/;
    }


    {
        # Test stream
        ok my $db = Bio::DB::Fasta->new( $test_file_mixed, -reindex => 1);
        ok my $stream = $db->get_PrimarySeq_stream;
        isa_ok $stream, 'Bio::DB::Indexed::Stream';
        my $count = 0;
        while (my $seq = $stream->next_seq) {
            $count++;
        }
        is $count, 5;
        $db->_rm_index;
    }


    {
        # Concurrent databases (bug #3390)
        ok my $db1 = Bio::DB::Fasta->new( $test_file_1, -clean => 1);
        ok my $db3 = Bio::DB::Fasta->new( $test_file_3, -clean => 1);
        ok my $db4 = Bio::DB::Fasta->new( $test_dir   , -clean => 1);
        ok my $db2 = Bio::DB::Fasta->new( $test_file_2, -clean => 1);
        is $db4->file('AW057231'), '1.fa';
        is $db2->file('AW057302'), '2.fa';
        is $db4->file('AW057119'), '1.fa';
        is $db3->file('AW057336'), '3.fa';
        is $db1->file('AW057231'), '1.fa';
        is $db4->file('AW057410'), '3.fa';
        is $db4->filepath('AW057231'), catfile($test_dir, '1.fa');
        is $db2->filepath('AW057302'), $test_file_2;
        is $db4->filepath('AW057119'), catfile($test_dir, '1.fa');
        is $db3->filepath('AW057336'), $test_file_3;
        is $db1->filepath('AW057231'), $test_file_1;
        is $db4->filepath('AW057410'), catfile($test_dir, '3.fa');
    }


    {
        # Test an arbitrary index filename and cleaning
        my $name = 'arbitrary.idx';
        ok my $db = Bio::DB::Fasta->new( $test_file_mixed,
            -reindex => 1, -index_name => $name, -clean => 1,
        );
        is $db->seq('gi|352962148|ref|NM_001251825.1|', 20, 29,  1), 'GUCAGCGUCC';

        is $db->index_name, $name;
        if ($dbi eq 'SDBM_File') {
            $name = $name.'.pag';
        }
        ok -f $name;

        $db->_rm_index;
        undef $db;
        ok ! -f $name;
    }


    {
        # Test makeid
        ok my $db = Bio::DB::Fasta->new( $test_file_mixed,
            -reindex => 1, -clean => 1, -makeid => \&extract_gi,
        ), 'Make single ID';
        is_deeply [sort $db->get_all_primary_ids], ['', 194473622, 352962132, 352962148, 61679760];
        is $db->get_Seq_by_id('gi|352962148|ref|NM_001251825.1|'), undef;
        isa_ok $db->get_Seq_by_id(194473622), 'Bio::PrimarySeqI';
    }


    {
        # Test makeid that generates several IDs, bug #3389
        ok my $db = Bio::DB::Fasta->new( $test_file_mixed,
            -reindex => 1, -clean => 1, -makeid => \&extract_gi_and_ref,
        ), 'Make multiple IDs, bug #3389';
        is_deeply [sort $db->get_all_primary_ids], ['', 194473622, 352962132, 352962148, 61679760, 'NG_030353.1',  'NM_001251825.1', 'NP_001123975.1'];
        is $db->get_Seq_by_id('gi|352962148|ref|NM_001251825.1|'), undef;
        isa_ok $db->get_Seq_by_id('NG_030353.1'), 'Bio::PrimarySeqI';
    }


    {
        # Test opening set of files and test IDs
        ok my $db = Bio::DB::Fasta->new( [$test_file_mixed, $test_file_6],
            -reindex => 1), 'Index a set of files';
        ok $db->ids;
        ok $db->get_all_ids;
        my @ids = sort $db->get_all_primary_ids();
        is_deeply \@ids, [ qw(
            123
            CEESC12R
            CEESC13F
            CEESC13R
            CEESC14F
            CEESC14R
            CEESC15F
            CEESC15R
            CEESC15RB
            CEESC16F
            CEESC17F
            CEESC17RB
            CEESC18F
            CEESC18R
            CEESC19F
            CEESC19R
            CEESC20F
            CEESC21F
            CEESC21R
            CEESC22F
            CEESC23F
            CEESC24F
            CEESC25F
            CEESC26F
            CEESC27F
            CEESC28F
            CEESC29F
            CEESC30F
            CEESC32F
            CEESC33F
            CEESC33R
            CEESC34F
            CEESC35R
            CEESC36F
            CEESC37F
            CEESC39F
            CEESC40R
            CEESC41F
            gi|194473622|ref|NP_001123975.1|
            gi|352962132|ref|NG_030353.1|
            gi|352962148|ref|NM_001251825.1|
            gi|61679760|pdb|1Y4P|B
        )];
        like $db->index_name, qr/^fileset_.+\.index$/;
        is $db->file('CEESC12R'), '6.fa';
        is $db->file('123'), 'mixed_alphabet.fasta';
        is $db->path(), '';
        is $db->filepath('CEESC12R'), $test_file_6;
        is $db->filepath('123'), $test_file_mixed;
        $db->_rm_index;
    }


    {
        # Squash warnings locally
        local $SIG{__WARN__} = sub {};
    
        # Issue 3172
        my $test_dir = setup_temp_dir('bad_dbfa');
        throws_ok {my $db = Bio::DB::Fasta->new($test_dir, -reindex => 1)}
            qr/FASTA header doesn't match/;

        # Issue 3237
        # Empty lines within a sequence is bad...
        throws_ok {my $db = Bio::DB::Fasta->new($test_file_bad, -reindex => 1)}
            qr/Blank lines can only precede header lines/;
    }


    {
        # Issue 3237 again
        # but empty lines preceding headers are okay, but let's check the seqs just in case
        my $db;
        lives_ok {$db = Bio::DB::Fasta->new($test_file_spaced, -reindex => 1)};
        is length($db->seq('CEESC39F')), 375, 'length is correct in sequences past spaces';
        is length($db->seq('CEESC13F')), 389;

        is $db->subseq('CEESC39F', 51, 60)  , 'acatatganc', 'subseq is correct';
        is $db->subseq('CEESC13F', 146, 155), 'ggctctccct', 'subseq is correct';

        # Remove temporary test file
        $db->_rm_index;
    }


    SKIP: {
        test_skip(-tests => 10, -requires_modules => [qw(Storable)]);
        # Test hooks to serialize via Storable

        {
            # Test freeze, thaw and dclone, on database and sequences
            ok my $db1 = Bio::DB::Fasta->new( $test_file_mixed, -reindex => 1, -clean => 1);
            ok my $serialized = Storable::freeze( $db1 );
            ok my $db2 = Storable::thaw( $serialized );
            ok my $db3 = Storable::dclone( $db1 );

            # Different objects, not just a link
            isnt $db1, $db2;
            isnt $db1, $db3;

            # Old and new databases should all be functional
            is $db1->seq('gi|352962148|ref|NM_001251825.1|', 20, 29,  1), 'GUCAGCGUCC';
            is $db2->seq('gi|352962148|ref|NM_001251825.1|', 20, 29,  1), 'GUCAGCGUCC';
            is $db3->seq('gi|352962148|ref|NM_001251825.1|', 20, 29,  1), 'GUCAGCGUCC';

        }

        {
            # Same thing for sequences
            ok my $db = Bio::DB::Fasta->new( $test_file_mixed, -reindex => 1, -clean => 1);
            ok my $seq1 = $db->get_Seq_by_id('gi|352962148|ref|NM_001251825.1|');
            ok my $serialized = Storable::freeze( $seq1 );
            ok my $seq2 = Storable::thaw( $serialized );
            ok my $seq3 = Storable::dclone( $seq1 );
            isnt $seq1, $seq2;
            isnt $seq1, $seq3;
            is $seq1->subseq(20, 29,  1), 'GUCAGCGUCC';
            is $seq2->subseq(20, 29,  1), 'GUCAGCGUCC';
            is $seq3->subseq(20, 29,  1), 'GUCAGCGUCC';
        }

        {
            # Again for sequences, but when database is out of scope

            sub get_db_seq {
                my $db = Bio::DB::Fasta->new( $test_file_mixed, -reindex => 1, -clean => 1);
                return $db->get_Seq_by_id('gi|352962148|ref|NM_001251825.1|');
            }

            ok my $seq1 = get_db_seq();
            ok my $serialized = Storable::freeze( $seq1 );
            ok my $seq2 = Storable::thaw( $serialized );
            ok my $seq3 = Storable::dclone( $seq1 );
            isnt $seq1, $seq2;
            isnt $seq1, $seq3;
            is $seq1->subseq(20, 29,  1), 'GUCAGCGUCC';
            is $seq2->subseq(20, 29,  1), 'GUCAGCGUCC';
            is $seq3->subseq(20, 29,  1), 'GUCAGCGUCC';
        }

    }


    SKIP: {
        skip("since this perl does not support threads", 10) if not $Config{useithreads};

        require_ok 'threads';
        my ($thr1, $thr2, $val1, $val2);

        sub worker_str {
            # Retrieve the 10 first residues for the given sequence ID
            my ($file, $id) = @_;
            my $db  = Bio::DB::Fasta->new($file);
            my $seq = $db->get_Seq_by_id($id);
            my $str = $seq->subseq(1,10);
            return $str;
        }

        sub worker_seq {
            # Retrieve a PrimarySeq object for the given sequence ID
            my ($file, $id) = @_;
            my $db  = Bio::DB::Fasta->new($file);
            my $seq = $db->get_Seq_by_id($id);
            return $seq;
        }


        {
            # Basic thread
            ok $thr1 = threads->create(\&worker_str, $test_dir, 'CEESA96F');
            ok $val1 = $thr1->join;
            is $val1, 'atattggcat';
        }


        {
            # Concurent threads. One is expected to create the index, while the
            # other waits for the indexing to be finished. Then both query the
            # db and retrieve the specified subsequence.

            my $large_fasta = setup_large_temp_file();

            $thr1 = threads->create(\&worker_str, $large_fasta, 'large_seq');
            $thr2 = threads->create(\&worker_str, $large_fasta, 'large_seq');
            $val2 = $thr2->join;
            if (my $err = $thr2->error()) {
                warn("Thread 2 error: $err\n");
            }
            $val1 = $thr1->join;
            if (my $err = $thr1->error()) {
                warn("Thread 1 error: $err\n");
            }
            is $val1, 'acgtacgtac';
            is $val2, 'acgtacgtac';
        }

        {
            skip("since returning a PrimarySeq from a thread segfaults", 3);

            ok $thr1 = threads->create(\&worker_seq, $test_dir, 'CEESA96F');
            ok $val1 = $thr1->join;
            isa_ok $val1, 'Bio::PrimarySeqI';
        }

    }


}
}

exit;



sub extract_gi {
    # Extract GI from RefSeq
    my $header = shift;
    my ($id) = ($header =~ /gi\|(\d+)/m);
    return $id || '';
}


sub extract_gi_and_ref {
    # Extract GI and from RefSeq
    my $header = shift;
    my ($gi)  = ($header =~ /gi\|(\d+)/m);
    $gi ||= '';
    my ($ref) = ($header =~ /ref\|([^|]+)/m);
    $ref ||= '';
    return $gi, $ref;
}


sub setup_temp_dir {
    # this obfuscation is to deal with lockfiles by GDBM_File which can
    # only be created on local filesystems apparently so will cause test
    # to block and then fail when the testdir is on an NFS mounted system
    my ($data_dir) = @_;
    my $io = Bio::Root::IO->new();
    my $tempdir = test_output_dir();
    my $test_dir = $io->catfile($tempdir, $data_dir);
    mkdir $test_dir; # make the directory
    my $indir = test_input_file($data_dir);
    opendir my $INDIR, $indir || die("cannot open dir $indir");
    # effectively do a cp -r but only copy the files that are in there, no subdirs
    for my $file ( map { $io->catfile($indir,$_) } readdir($INDIR) ) {
        next unless (-f $file );
        copy $file, $test_dir or die "Copy error: $!\n";
    }
    closedir $INDIR;
    return $test_dir
}


sub setup_temp_file {
    my (@path) = @_;
    my $filebase = $path[-1];
    my $ori = test_input_file( @path );
    my $io = Bio::Root::IO->new();
    my $tempdir = test_output_dir();
    my $tempfile = $io->catfile($tempdir, $filebase);
    copy $ori, $tempfile or die "Copy error: $!\n";
    return $tempfile;
}


sub setup_large_temp_file {
    my $large_fasta = test_output_file();
    my $out = Bio::SeqIO->new( -file => '>'.$large_fasta, -format => 'fasta');
    $out->write_seq(
        Bio::PrimarySeq->new(-id => 'large_seq', -seq => 'acgtacgtac' x 1_000_000)
    );  # 10 Mbp seq
    return $large_fasta;
}
