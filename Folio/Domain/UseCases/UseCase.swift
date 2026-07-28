import Foundation

protocol UseCase {
    associatedtype Input
    associatedtype Output

    func execute(input: Input) async throws -> Output
}

protocol NoInputUseCase {
    associatedtype Output

    func execute() async throws -> Output
}
