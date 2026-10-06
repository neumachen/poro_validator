require "spec_helper"
require "rubygems/package"
require "fileutils"
require "open3"
require "digest"
require "tmpdir"

PROJECT_ROOT = File.expand_path("../../../../", __FILE__)
GEMSPEC_PATH = File.join(PROJECT_ROOT, "poro_validator.gemspec")

RSpec.describe "Package manifest" do
  let(:spec) { Gem::Specification.load(GEMSPEC_PATH) }
  let(:project_root) { PROJECT_ROOT }
  let(:expected_lib_files) do
    Dir.glob(File.join(project_root, "lib", "**", "*"), File::FNM_DOTMATCH)
      .select { |f| File.file?(f) }
      .map { |f| f.sub("#{project_root}/", "") }
      .sort
  end

  # Recursively snapshot all source files excluding known generated artifacts.
  # Returns [relative_file_paths, {path => sha256_hex}].
  #
  # Uses path-boundary matching so that `.gitignore`, `.github/`, `.travis.yml`,
  # and `.simplecov` are preserved while `.git/`, `tmp/`, `pkg`, `coverage`,
  # and `.bundle/` directories are excluded.
  def snapshot_source(dir)
    sep = File::SEPARATOR
    exclude_dirs = [".git#{sep}", "tmp#{sep}", "pkg#{sep}", "coverage#{sep}", ".bundle#{sep}"]
    files = Dir.glob(File.join(dir, "**", "*"), File::FNM_DOTMATCH)
      .select { |f| File.file?(f) }
      .map { |f| f.sub("#{dir}#{sep}", "") }
      .reject { |f| exclude_dirs.any? { |e| f.start_with?(e) } || f.end_with?(".gem") }
      .sort

    hashes = {}
    files.each { |f| hashes[f] = Digest::SHA256.file(File.join(dir, f)).hexdigest }
    [files, hashes]
  end

  # Copy project to a temp directory, excluding .git, tmp, and .bundle.
  def copy_project_to(dest)
    entries = Dir.glob("*", File::FNM_DOTMATCH).reject { |f|
      f == ".git" || f == "tmp" || f == "." || f == ".." || f == ".bundle"
    }
    FileUtils.cp_r(entries, dest)
  end

  # Extract gem payload to a temp directory and return extracted file paths.
  def extract_gem_payload(gem_file, dest_dir)
    pkg = Gem::Package.new(gem_file)
    pkg.extract_files(dest_dir)
    Dir.glob(File.join(dest_dir, "**", "*"), File::FNM_DOTMATCH)
      .select { |f| File.file?(f) }
      .map { |f| f.sub("#{dest_dir}#{File::SEPARATOR}", "") }
      .sort
  end

  # Extract gem payload and return paths, content hashes, and metadata.
  def extract_gem_with_hashes(gem_file, dest_dir)
    paths = extract_gem_payload(gem_file, dest_dir)
    hashes = {}
    paths.each { |p| hashes[p] = Digest::SHA256.file(File.join(dest_dir, p)).hexdigest }

    pkg = Gem::Package.new(gem_file)
    metadata = gem_metadata_from_spec(pkg.spec)

    { paths: paths, hashes: hashes, metadata: metadata }
  end

  # Extract relevant metadata from a gem specification for comparison.
  def gem_metadata_from_spec(spec)
    {
      name: spec.name,
      version: spec.version.to_s,
      required_ruby_version: spec.required_ruby_version.to_s,
      runtime_dependencies: spec.dependencies
        .select { |d| d.type == :runtime }
        .map { |d| [d.name, d.requirement.to_s] }
        .sort
    }
  end

  # Return the complete expected payload paths from the gemspec.
  def expected_payload_paths
    spec.files.sort
  end

  def find_gem(dir)
    Dir.glob(File.join(dir, "*.gem")).first
  end

  def gem_payload(gem_file)
    Gem::Package.new(gem_file).contents.sort
  end

  def build_direct(dir)
    output, status = Open3.capture2e("gem build poro_validator.gemspec", chdir: dir)
    [output, status]
  end

  def build_via_rake(dir)
    if defined?(Bundler)
      Bundler.with_unbundled_env do
        output, status = Open3.capture2e('rake build', chdir: dir)
        [output, status]
      end
    else
      output, status = Open3.capture2e('rake build', chdir: dir)
      [output, status]
    end
  end

  # Run rake with synchronous stdout to capture diagnostics from exit! calls.
  # Clears inherited Bundler environment so Rake runs cleanly from bundle exec.
  # Searches the filesystem for the Rake executable since Bundler restricts
  # Gem::Specification.find to bundled gems only.
  # Returns [output, error, status].
def run_rake_with_diagnostic(dir, task)
  output_file = File.join(dir, '.rake_output')
  error_file = File.join(dir, '.rake_error')
  # Find rake executable by searching common paths
  rake_path = Dir.glob("/usr/local/lib/ruby/gems/*/gems/rake-*/exe/rake").find { |f| File.executable?(f) }
  rake_path ||= Dir.glob("/usr/lib/ruby/gems/*/gems/rake-*/exe/rake").find { |f| File.executable?(f) }
  rake_path ||= "/usr/bin/rake"
  
  # Create a wrapper script that redirects output before loading rake
  wrapper = File.join(dir, '.rake_wrapper.rb')
  File.write(wrapper, <<~WRAPPER)
    ENV['BUNDLE_GEMFILE'] = nil
    ENV['RUBYOPT'] = nil
    $stdout.reopen(#{output_file.inspect}, 'w')
    $stderr.reopen(#{error_file.inspect}, 'w')
    $stdout.sync = true
    $stderr.sync = true
    load #{rake_path.inspect}
  WRAPPER
  
  env = {
    'BUNDLE_GEMFILE' => nil,
    'RUBYOPT' => nil,
    'RUBYLIB' => nil,
    'BUNDLE_PATH' => nil,
    'BUNDLE_FROZEN' => nil,
    'BUNDLE_IGNORE_CONFIG' => nil,
    'GEM_PATH' => ENV['GEM_PATH']
  }
  
  if defined?(Bundler)
    Bundler.with_unbundled_env do
      pid = Process.spawn('ruby', wrapper, task, chdir: dir)
      Process.wait(pid)
    end
  else
    pid = Process.spawn(env, 'ruby', wrapper, task, chdir: dir)
    Process.wait(pid)
  end
  status = $?
  output = File.exist?(output_file) ? File.read(output_file) : ''
  error = File.exist?(error_file) ? File.read(error_file) : ''
  FileUtils.rm_f([output_file, error_file, wrapper])
  [output, error, status]
end

  around(:each) do |example|
    @tmpdirs = []
    example.run
  ensure
    @tmpdirs.each { |d| FileUtils.rm_rf(d) if File.directory?(d) }
  end

  def mktmpdir
    d = Dir.mktmpdir
    @tmpdirs << d
    d
  end

  # -- Gemspec structure tests (preserved) --

  it "includes every file under lib/" do
    lib_in_spec = spec.files.select { |f| f.start_with?("lib/") }.sort
    expect(lib_in_spec).to eq(expected_lib_files)
  end

  it "includes documentation and the gemspec" do
    %w[README.md LICENSE.txt CODE_OF_CONDUCT.md].each { |f| expect(spec.files).to include(f) }
    expect(spec.files).to include("poro_validator.gemspec")
  end

  it "excludes development, tooling and spec files" do
    excluded = %w[Gemfile Gemfile.test Gemfile.test.lock Rakefile Dockerfile
                  compose.yaml mise.toml .simplecov .travis.yml]
    excluded.each { |f| expect(spec.files).not_to include(f) }
    expect(spec.files.none? { |f| f.start_with?("spec/") }).to be(true)
  end

  describe "actual gem build" do
    it "builds a .gem directly and its payload matches spec.files" do
      dest = mktmpdir
      copy_project_to(dest)
      output, status = build_direct(dest)
      expect(status.exitstatus).to eq(0), "build failed: #{output[0..500]}"
      gem_file = find_gem(dest)
      expect(gem_file).not_to be_nil
      expect(gem_payload(gem_file)).to eq(spec.files.sort)
    end

    it "excludes spec files from the actual payload" do
      dest = mktmpdir
      copy_project_to(dest)
      FileUtils.mkdir_p(File.join(dest, "spec", "temp_test"))
      File.write(File.join(dest, "spec", "temp_test", "fake.rb"), "# fake")
      File.write(File.join(dest, "temp_evidence.txt"), "evidence")

      output, status = build_direct(dest)
      expect(status.exitstatus).to eq(0), "build failed: #{output[0..500]}"
      gem_file = find_gem(dest)
      payload = gem_payload(gem_file)
      expect(payload.none? { |f| f.start_with?("spec/") }).to be(true)
      expect(payload).not_to include("temp_evidence.txt")
    end

    it "includes a new file added under lib/" do
      dest = mktmpdir
      copy_project_to(dest)
      File.write(File.join(dest, "lib", "poro_validator", "temp_helper.rb"), "# helper")

      output, status = build_direct(dest)
      expect(status.exitstatus).to eq(0), "build failed: #{output[0..500]}"
      gem_file = find_gem(dest)
      expect(gem_payload(gem_file)).to include("lib/poro_validator/temp_helper.rb")
    end

    it "fails to build when LICENSE.txt is missing" do
      dest = mktmpdir
      copy_project_to(dest)
      FileUtils.rm(File.join(dest, "LICENSE.txt"))

      output, status = build_direct(dest)
      expect(status.exitstatus).not_to eq(0), "build should fail without LICENSE.txt"
    end

    it "preserves all source files after repeat builds" do
      dest = mktmpdir
      copy_project_to(dest)

      before_files, before_hashes = snapshot_source(dest)

      output1, status1 = build_direct(dest)
      expect(status1.exitstatus).to eq(0), "first build failed: #{output1[0..500]}"
      FileUtils.rm_f(find_gem(dest))

      output2, status2 = build_direct(dest)
      expect(status2.exitstatus).to eq(0), "second build failed: #{output2[0..500]}"

      after_files, after_hashes = snapshot_source(dest)

      expect(after_files).to eq(before_files)
      expect(after_hashes).to eq(before_hashes)
    end

    it "validates packaged runtime bytes match source" do
      dest = mktmpdir
      copy_project_to(dest)

      # Capture pre-build source BEFORE building
      before_files, before_hashes = snapshot_source(dest)

      output, status = build_direct(dest)
      expect(status.exitstatus).to eq(0), "build failed: #{output}"
      gem_file = find_gem(dest)

      extract_dir = mktmpdir
      extracted = extract_gem_payload(gem_file, extract_dir)

      # Get the complete expected payload set from the gemspec
      expected_paths = expected_payload_paths

      # Assert extracted paths EXACTLY match expected (no missing, no unexpected)
      expect(extracted).to eq(expected_paths),
        "Extracted paths don't match expected. Missing: #{(expected_paths - extracted).inspect}, Extra: #{(extracted - expected_paths).inspect}"

      # Assert non-trivial payload (more than just 1 file)
      expect(extracted.length).to be > 1,
        "Payload should contain more than 1 file"

      # Every extracted file must exist in source and match bytes exactly
      extracted.each do |rel|
        expect(before_hashes).to have_key(rel),
          "Extracted file #{rel} not in pre-build source"
        ext_digest = Digest::SHA256.file(File.join(extract_dir, rel)).hexdigest
        expect(ext_digest).to eq(before_hashes[rel]),
          "Byte mismatch for #{rel}: pre-build=#{before_hashes[rel]}, extracted=#{ext_digest}"
      end
    end
  end

  describe "gemspec loads correctly from any directory" do
    it "uses absolute paths so it loads correctly from any directory" do
      dest = mktmpdir
      copy_project_to(dest)

      # Load from the project root
      Gem::Specification.reset
      spec_root = Gem::Specification.load(File.join(dest, "poro_validator.gemspec"))
      files_from_root = spec_root.files.sort

      # Load from a completely different directory
      other_dir = mktmpdir
      FileUtils.mkdir_p(other_dir)
      Gem::Specification.reset
      files_from_other = Dir.chdir(other_dir) do
        Gem::Specification.load(File.join(dest, "poro_validator.gemspec")).files.sort
      end

      # Both must produce identical file sets
      expect(files_from_root).to eq(files_from_other)
      expect(files_from_root).not_to be_empty
      lib_files = files_from_root.select { |f| f.start_with?("lib/") }
      expect(lib_files).not_to be_empty
      expect(files_from_root).to include("lib/poro_validator/utils/stable_inspect.rb")
    end

    it "rejects gemspec using caller-relative paths" do
      dest = mktmpdir
      bad_gemspec = File.join(dest, "bad.gemspec")
      File.write(bad_gemspec, <<~RB)
        Gem::Specification.new do |s|
          s.name = "bad"
          s.version = "0.0.1"
          base = "."
          s.files = Dir.glob(File.join(base, "lib", "**", "*"), File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
          s.files << "README.md"
        end
      RB

      other_dir = mktmpdir
      loaded_files = Dir.chdir(other_dir) do
        Gem::Specification.reset
        spec = Gem::Specification.load(bad_gemspec)
        spec.files.sort
      end

      lib_files = loaded_files.select { |f| f.start_with?("lib/") }
      expect(lib_files).to be_empty, "caller-relative gemspec should find no lib files from different dir"
    end
  end

  describe "Rake build equivalence" do
    it "produces the same payload and metadata via direct gem build and rake build" do
      dest_direct = mktmpdir
      copy_project_to(dest_direct)
      before_files_direct, before_hashes_direct = snapshot_source(dest_direct)
      out1, st1 = build_direct(dest_direct)
      expect(st1.exitstatus).to eq(0), "direct build failed: #{out1[0..500]}"
      gem_direct = find_gem(dest_direct)
      expect(gem_direct).not_to be_nil

      dest_rake = mktmpdir
      copy_project_to(dest_rake)
      before_files_rake, before_hashes_rake = snapshot_source(dest_rake)
      out2, st2 = build_via_rake(dest_rake)
      expect(st2.exitstatus).to eq(0), "rake build failed: #{out2}"
      gem_rake = find_gem(File.join(dest_rake, "pkg"))
      expect(gem_rake).not_to be_nil

      # Extract both with hashes and metadata
      extract_dir_direct = mktmpdir
      result_direct = extract_gem_with_hashes(gem_direct, extract_dir_direct)

      extract_dir_rake = mktmpdir
      result_rake = extract_gem_with_hashes(gem_rake, extract_dir_rake)

      # Compare complete path sets
      expect(result_rake[:paths]).to eq(result_direct[:paths]),
        "Path sets differ between direct and rake builds"

      # Compare each artifact against its own pre-build source
      result_direct[:paths].each do |path|
        expect(before_hashes_direct).to have_key(path),
          "Direct: #{path} not in pre-build source"
        expect(result_direct[:hashes][path]).to eq(before_hashes_direct[path]),
          "Direct: byte mismatch for #{path}"
      end

      result_rake[:paths].each do |path|
        expect(before_hashes_rake).to have_key(path),
          "Rake: #{path} not in pre-build source"
        expect(result_rake[:hashes][path]).to eq(before_hashes_rake[path]),
          "Rake: byte mismatch for #{path}"
      end

      # Compare artifacts against each other
      result_direct[:paths].each do |path|
        expect(result_rake[:hashes][path]).to eq(result_direct[:hashes][path]),
          "Content mismatch for #{path} between direct and rake builds"
      end

      # Compare relevant metadata
      expect(result_rake[:metadata]).to eq(result_direct[:metadata]),
        "Metadata differs between direct and rake builds"
    end
  end

  describe "Rake preflight rejection" do
    it "fails both gemspec and build when a root VERSION fixture exists" do
      dest = mktmpdir
      copy_project_to(dest)
      File.write(File.join(dest, "VERSION"), "9.9.9\n")

      out_gemspec, err_gemspec, st_gemspec = run_rake_with_diagnostic(dest, "gemspec")
      expect(st_gemspec.exitstatus).not_to eq(0),
        "rake gemspec should fail with VERSION fixture. stdout: #{out_gemspec.inspect}, stderr: #{err_gemspec.inspect}"
      expect(out_gemspec).to match(/A `VERSION` file at root level violates Gem best practices\./),
        "rake gemspec should report VERSION rejection, got: #{out_gemspec.inspect}"

      out_build, err_build, st_build = run_rake_with_diagnostic(dest, "build")
      expect(st_build.exitstatus).not_to eq(0),
        "rake build should fail with VERSION fixture. stdout: #{out_build.inspect}, stderr: #{err_build.inspect}"
      expect(out_build).to match(/A `VERSION` file at root level violates Gem best practices\./),
        "rake build should report VERSION rejection, got: #{out_build.inspect}"

      # No artifact should appear
      expect(Dir.glob(File.join(dest, "pkg", "*.gem"))).to be_empty
      expect(Dir.glob(File.join(dest, "*.gem"))).to be_empty
    end
  end
end
