Model.new(:volumes, 'Backup docker volumes mounted in /volData') do
  sync_with RSync::Push do |sync|
    sync.directories do |dir|
      dir.add '/volData'
    end
  end

  notify_by Mail
end
