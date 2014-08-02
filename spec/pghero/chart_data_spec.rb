module PgHero
  describe ChartData do
    describe '#series' do
      let(:input) do
        [ [ 'Name 1', 10 ],
          [ 'Name 2', 20 ],
          [ 'Name 3', 30 ],
          [ 'Name 4', 5 ],
          [ 'Name 5', 4 ],
          [ 'Name 6', 1 ],
          [ 'Name 7', 25 ],
          [ 'Name 8', 1 ],
          [ 'Name 9', 4 ] ]
      end

      subject { described_class.new(input).series(6) }

      its([0]) { should eq ['Name 3', 30] }
      its([1]) { should eq ['Name 7', 25] }
      its([2]) { should eq ['Name 2', 20] }
      its([3]) { should eq ['Name 1', 10] }
      its([4]) { should eq ['Name 4', 5] }
      its([5]) { should eq ['Others', 10] }
    end
  end
end
