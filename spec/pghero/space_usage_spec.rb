module PgHero
  describe SpaceUsage do
    let(:relation_sizes) do
      [
        { 'name' => 'index_posts_on_title', 'type' => 'index', 'size' => 1_000_000.to_s },
        { 'name' => 'posts', 'type' => 'table', 'size' => 8_540_000.to_s },
        { 'name' => 'comments', 'type' => 'table', 'size' => 460_000.to_s }
      ]
    end

    subject(:space_usage) { described_class.new 10_000_000.to_s, relation_sizes }

    its(:total) { should eq 10_000_000 }

    describe '#relations' do
      describe '[0]' do
        subject { space_usage.relations[0] }

        its(:name) { should eq 'index_posts_on_title' }
        its(:type) { should eq 'index' }
        its(:size) { should eq 1_000_000 }
        its(:size_percentage) { should eq 10 }
      end

      describe '[1]' do
        subject { space_usage.relations[1] }

        its(:name) { should eq 'posts' }
        its(:type) { should eq 'table' }
        its(:size) { should eq 8_540_000 }
        its(:size_percentage) { should be_within(0.1).of(85.3) }
      end

      describe '[2]' do
        subject { space_usage.relations[2] }

        its(:name) { should eq 'comments' }
        its(:type) { should eq 'table' }
        its(:size) { should eq 460_000 }
        its(:size_percentage) { should be_within(0.1).of(4.6) }
      end
    end
  end
end
