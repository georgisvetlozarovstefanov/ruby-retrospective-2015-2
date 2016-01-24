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
    message = "Added #{name} to stage."

    Feedback.new(message, true, object)
  end

  def has_commits?
    branch.commits.any?
  end


  def remove(name)
    error = "Object #{name} is not committed."
    success = "Added #{name} for removal."

    object = current_branch.commits.last.state[name] if has_commits?
    object = nil unless has_commits?
    deleted[name] = object if object


    object ? Feedback.new(success, true, object) :
             Feedback.new(error, false)
  end

  def commit(message)
    changed, count = (stage.any? or deleted.any?), stage.merge(deleted).size
    error = "Nothing to commit, working directory clean."
    success = "#{message}" + "\n\t#{count} objects changed."

    new_state = {}.merge(stage).reject { |name| deleted.has_key?(name) }

    new_state = branch.commits.last.state.merge(stage).
                reject { |name| deleted.has_key?(name) } if has_commits?

    result = Commit.new(new_state, message)
    current_branch.commits.push(result) if changed

    @stage, @deleted = {}, {}
    changed ? Feedback.new(success, true, result) : Feedback.new(error, false)
  end

  def checkout(commit_hash)
    error = "Commit #{commit_hash} does not exist."
    success = "HEAD is now at #{commit_hash}."

    hash_values = branch.commits.map { |commit| commit.hash }
    has_hash = hash_values.include?(commit_hash)

    last_commit = hash_values.find_index(commit_hash) if has_hash
    branch.commits.slice!(last_commit + 1...branch.commits.size) if has_hash
    result = branch.commits.last

    has_hash ? Feedback.new(success, true, result) : Feedback.new(error, false)
  end

  def branch
    current_branch
  end

  def log
    error = "Branch #{branch.name} does not have any commits yet."

    success = branch.commits.map do |commit|
      "Commit #{ commit.hash }\nDate: " \
      "#{ commit.date }\n\n\t#{ commit.message }"
    end
    success = success.reverse.join("\n\n")

    has_commits? ? Feedback.new(success, true) : Feedback.new(error, false)
  end

  def get(name)
    error = "Object #{ name } is not committed."
    success = "Found object #{ name }."

    result = branch.commits.last.state[name] if has_commits?
    is_committed = branch.commits.last.state.has_key?(name) if has_commits?

    (has_commits? and is_committed) ? Feedback.new(success, true, result) :
                                      Feedback.new(error, false)
  end

  def head
    error = "Branch #{ branch.name } does not have any commits yet."
    success = "#{ branch.commits.last.message }" if has_commits?
    result = branch.commits.last if has_commits?

    has_commits? ? Feedback.new(success, true, result) :
                   Feedback.new(error, false)
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
    success = "Created branch #{ name }."
    error = "Branch #{ name } already exists."

    name_taken = has_branch?(name)

    branch_out = Branch.new(name, repository) unless name_taken
    branch_out.commits = commits.dup unless name_taken
    repository.branches << branch_out unless name_taken

    name_taken ? Feedback.new(error, false) :
                 Feedback.new(success, true)
  end

  def checkout(name)
    success = "Switched to branch #{ name }."
    error = "Branch #{ name } does not exist."

    new_current = nil
    repository.branches.each do |branch|
      new_current = branch if branch.name == name
    end
    repository.current_branch = new_current if new_current

    new_current ? Feedback.new(success, true) : Feedback.new(error, false)
  end

  def remove(name)
    success = "Removed branch #{ name }."
    error_current = "Cannot remove current branch."
    no_branch = "Branch #{ name } does not exist."

    is_current = name == repository.branch.name
    no_problem = (has_branch?(name) and not is_current)

    repository.branches.keep_if { |branch| branch.name != name } if no_problem

    no_problem ? Feedback.new(success, true) :
                 is_current ? Feedback.new(error_current, false) :
                              Feedback.new(no_branch, false)
  end

  def list
    named = repository.branches.map { |branch| branch.name }
    sorted = named.sort!

    sorted.
    map! { |name| name == repository.branch.name ? " *" + name : "  " + name }
    message = sorted.join("\n")

    Feedback.new("#{ message }", true)
  end

end

class Commit
  attr_accessor :state, :message

  def initialize(state, message)
    @state = state
    @message = message
    @date = Time.now
  end

  def date
    @date.strftime('%a %b %-d %H:%M %Y %z')
  end

  def hash
    Digest::SHA1.hexdigest(date.to_s + message)
  end

  def objects
    state.values
  end
end