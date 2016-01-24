require 'digest/sha1'

class Feedback
  attr_accessor :message

  def initialize(message, success, result = nil)
    @message = message
    @success = success
    @result = result
  end

  def success?
    @success == true
  end

  def error?
    @success == false
  end

  def result
    @result == nil ?
      begin raise NoMethodError, "No 'result' method for this action." end :
      @result
  end
end

class Messages
  def self.add(name)
    return "Added #{name} to stage."
  end
  def self.remove_object(name, success)
    return "Added #{name} for removal." if success
    "Object #{name} is not committed."
  end
  def self.commit(message = nil, count = nil, success)
    return "#{message}" + "\n\t#{count} objects changed" if success
    "Nothing to commit, working directory clean."
  end

  def self.checkout(commit_hash, success)
    return "HEAD is now at #{commit_hash}." if success
    "Commit #{commit_hash} does not exist."
  end

  def self.log(branch, success)
    return "Branch #{branch.name} does not have any commits yet." if ! success
     success = branch.commits.map do |commit|
      "Commit #{ commit.hash }\nDate: " \
      "#{ commit.date_s}\n\n\t#{ commit.message }"
    end
    success = success.reverse.join("\n\n")
    success
  end

  def self.get(name, success)
    return "Found object #{ name }." if success
    "Object #{ name } is not committed."
  end

  def self.head(branch, success)
   return "#{ branch.commits.last.message }" if success
   "Branch #{ branch.name } does not have any commits yet."
  end

  def self.branch_new(name, success)
    return "Created branch #{ name }." if success
    "Branch #{ name } already exists."
  end

  def self.branch_checkout(name, success)
    return "Switched to branch #{ name }." if success
    "Branch #{ name } does not exist."
  end

  def self.branch_remove(name, status)
    return "Removed branch #{ name }." if status == 0
    return "Cannot remove current branch." if status == 1
    return "Branch #{ name } does not exist." if status == 2
  end
end

class ObjectStore
  attr_accessor :stage, :deleted, :branches, :current_branch

  def self.init(&block)
    repository, repository.stage, repository.deleted = self.new, {}, {}
    master_branch = Branch.new("master", repository)

    repository.branches, repository.current_branch = [], master_branch
    repository.branches << master_branch

    repository.instance_eval(&block) if block_given?
    repository
  end

  def add(name, object)
    stage[name] = object

    Feedback.new(Messages.add(name), true, object)
  end

  def has_commits?
    branch.commits.any?
  end


  def remove(name)
    object = current_branch.commits.last.state[name] if has_commits?
    object = nil unless has_commits?
    deleted[name] = object if object


    object ? Feedback.new(Messages.remove_object(name, true), true, object) :
             Feedback.new(Messages.remove_object(name, false), false)
  end

  def new_state
     state = {}.merge(stage).reject { |name| deleted.has_key?(name) }

     state = branch.commits.last.state.merge(stage).
             reject { |name| deleted.has_key?(name) } if has_commits?
     state
  end
  def commit(message)
    changed, count = (stage.any? or deleted.any?), stage.merge(deleted).size
    return Feedback.new(Messages.commit(false), false) if not changed

    result = Commit.new(new_state, message)
    current_branch.commits.push(result)

    @stage, @deleted = {}, {}
    Feedback.new(Messages.commit(message, count, true), true, result)
  end

  def checkout(commit_hash)
    hash_values = branch.commits.map { |commit| commit.hash }
    last_commit = hash_values.find_index(commit_hash)

    if not last_commit
      return Feedback.new(Messages.checkout(commit_hash, false), false)
    end
    branch.commits = branch.commits[0..last_commit]
    result = branch.commits.last

    Feedback.new(Messages.checkout(commit_hash, true), true, result)
  end

  def branch
    current_branch
  end

  def log
    return Feedback.new(Messages.log(branch, false), false) if not has_commits?
    Feedback.new(Messages.log(branch, true), true)
  end

  def get(name)
    return Feedback.new(Messages.get(name, false), false) if not has_commits?
    result = branch.commits.last.state[name]
    is_committed = branch.commits.last.state.has_key?(name)

    is_committed ? Feedback.new(Messages.get(name, true), true, result) :
                   Feedback.new(Messages.get(name, false), false)
  end

  def head
    return Feedback. new(Messages.head(branch, false), false) if ! has_commits?
    result = branch.commits.last
    Feedback.new(Messages.head(branch,true), true, result)
  end
end

class Branch
  attr_accessor :name, :repository, :commits

  def initialize(name, repository)
    @name = name
    @repository = repository
    @commits = []
  end

  def has_branch?(name)
    repository.branches.any? { |branch| branch.name == name }
  end

  def create(name)
    name_taken = has_branch?(name)
    return Feedback.new(Messages.branch_new(name, false), false) if name_taken

    branch_out = Branch.new(name, repository)
    branch_out.commits = commits.dup
    repository.branches << branch_out

    Feedback.new(Messages.branch_new(name, true), true)
  end

  def checkout(name)
    new_current = nil
    repository.branches.each do |branch|
      new_current = branch if branch.name == name
    end
    repository.current_branch = new_current if new_current

    new_current ? Feedback.new(Messages.branch_checkout(name, true), true) :
                  Feedback.new(Messages.branch_checkout(name, false), false)
  end

  def remove(name)
    is_current = name == repository.branch.name

    return Feedback.new(Messages.branch_remove(name, 1), false) if is_current

    if not has_branch?(name)
      return Feedback.new(Messages.branch_remove(name, 2), false)
    else
      repository.branches.keep_if { |branch| branch.name != name }
      return Feedback.new(Messages.branch_remove(name, 0), true)
    end
  end

  def list
    named = repository.branches.map { |branch| branch.name }
    sorted = named.sort!

    sorted.
    map! { |name| name == repository.branch.name ? "* " + name : "  " + name }
    message = sorted.join("\n")

    Feedback.new("#{ message }", true)
  end
end
class Commit
  attr_accessor :state, :message, :hash

  def initialize(state, message)
    @state = state
    @message = message
    @date = Time.now
    @hash = Digest::SHA1.hexdigest(date_s + message)
  end

  def date
    @date
  end

  def date_s
    @date.strftime('%a %b %-d %H:%M %Y %z')
  end

  def objects
    state.values
  end
end